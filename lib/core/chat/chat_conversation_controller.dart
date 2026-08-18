import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum ChatSendOutcome {
  success,
  uncertain,
  retryableFailure,
  permanentFailure,
}

enum ChatDeliveryState { sending, checking, sent, failed }

enum ChatConversationState { loading, ready, unavailable, loadFailed }

class ChatSendResult {
  const ChatSendResult._(this.outcome, {this.message});

  const ChatSendResult.success(Map<String, dynamic> message)
      : this._(ChatSendOutcome.success, message: message);

  const ChatSendResult.uncertain() : this._(ChatSendOutcome.uncertain);

  const ChatSendResult.retryableFailure()
      : this._(ChatSendOutcome.retryableFailure);

  const ChatSendResult.permanentFailure()
      : this._(ChatSendOutcome.permanentFailure);

  final ChatSendOutcome outcome;
  final Map<String, dynamic>? message;
}

abstract interface class ChatGateway {
  Future<bool> resolveAccess(String matchId);

  Future<List<Map<String, dynamic>>> loadMessages(String matchId);

  Stream<List<Map<String, dynamic>>> realtimeMessages(String matchId);

  Future<ChatSendResult> sendMessage({
    required String matchId,
    required String body,
    required String messageId,
  });

  Future<Map<String, dynamic>?> findMessageById({
    required String matchId,
    required String messageId,
  });
}

typedef ChatMessageIdFactory = String Function();

class ChatConversationController extends ChangeNotifier {
  ChatConversationController({
    required this.gateway,
    required this.matchId,
    required this.senderId,
    ChatMessageIdFactory? createMessageId,
  }) : _createMessageId = createMessageId ?? createChatMessageId;

  final ChatGateway gateway;
  final String matchId;
  final String senderId;
  final ChatMessageIdFactory _createMessageId;

  ChatConversationState state = ChatConversationState.loading;
  List<Map<String, dynamic>> messages = const [];
  bool realtimeFailed = false;
  bool sendInProgress = false;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _disposed = false;

  Future<void> initialize() async {
    state = ChatConversationState.loading;
    _notify();
    try {
      if (matchId.isEmpty || !await gateway.resolveAccess(matchId)) {
        state = ChatConversationState.unavailable;
        _notify();
        return;
      }
      messages =
          mergeChatMessages(messages, await gateway.loadMessages(matchId));
      state = ChatConversationState.ready;
      _notify();
      _listenToRealtime();
    } catch (_) {
      state = ChatConversationState.loadFailed;
      _notify();
    }
  }

  Future<bool> send(String body) async {
    final trimmed = body.trim();
    if (state != ChatConversationState.ready ||
        sendInProgress ||
        trimmed.isEmpty) {
      return false;
    }
    final messageId = _createMessageId();
    messages = mergeChatMessages(messages, [
      {
        'id': messageId,
        'match_id': matchId,
        'sender_id': senderId,
        'body': trimmed,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        '_delivery_state': ChatDeliveryState.sending.name,
        '_optimistic': true,
      },
    ]);
    sendInProgress = true;
    _notify();
    await _submit(messageId);
    return true;
  }

  Future<void> retry(String messageId) async {
    if (sendInProgress) return;
    final row = _message(messageId);
    if (row == null ||
        row['_delivery_state'] != ChatDeliveryState.failed.name) {
      return;
    }
    _setDeliveryState(messageId, ChatDeliveryState.sending);
    sendInProgress = true;
    _notify();
    await _submit(messageId);
  }

  Future<void> _submit(String messageId) async {
    final row = _message(messageId);
    if (row == null) return;
    ChatSendResult result;
    try {
      result = await gateway.sendMessage(
        matchId: matchId,
        body: row['body'] as String? ?? '',
        messageId: messageId,
      );
    } catch (_) {
      result = const ChatSendResult.uncertain();
    }

    switch (result.outcome) {
      case ChatSendOutcome.success:
        _reconcileServerRows([if (result.message != null) result.message!]);
        _setDeliveryState(messageId, ChatDeliveryState.sent);
      case ChatSendOutcome.uncertain:
        _setDeliveryState(messageId, ChatDeliveryState.checking);
        await _readBack(messageId);
      case ChatSendOutcome.retryableFailure:
      case ChatSendOutcome.permanentFailure:
        _setDeliveryState(messageId, ChatDeliveryState.failed);
    }
    sendInProgress = false;
    _notify();
    await refresh(silent: true);
  }

  Future<void> _readBack(String messageId) async {
    try {
      final row = await gateway.findMessageById(
        matchId: matchId,
        messageId: messageId,
      );
      if (row != null) _reconcileServerRows([row]);
    } catch (_) {
      // The result remains uncertain; realtime or a later refresh can resolve it.
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (state != ChatConversationState.ready) return;
    try {
      _reconcileServerRows(await gateway.loadMessages(matchId));
    } catch (_) {
      if (!silent && messages.isEmpty) {
        state = ChatConversationState.loadFailed;
        _notify();
      }
    }
  }

  void _listenToRealtime() {
    _subscription?.cancel();
    _subscription = gateway.realtimeMessages(matchId).listen(
      _reconcileServerRows,
      onError: (_) {
        realtimeFailed = true;
        _notify();
      },
    );
  }

  void _reconcileServerRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    final acknowledged = rows
        .map((row) => <String, dynamic>{
              ...row,
              '_delivery_state': ChatDeliveryState.sent.name,
              '_optimistic': false,
            })
        .toList();
    messages = mergeChatMessages(messages, acknowledged);
    realtimeFailed = false;
    _notify();
  }

  void _setDeliveryState(String id, ChatDeliveryState deliveryState) {
    messages = [
      for (final row in messages)
        if (row['id'] == id)
          {...row, '_delivery_state': deliveryState.name}
        else
          row,
    ];
    _notify();
  }

  Map<String, dynamic>? _message(String id) {
    for (final row in messages) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

List<Map<String, dynamic>> mergeChatMessages(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> incoming,
) {
  final next = List<Map<String, dynamic>>.of(current);
  final indexes = <String, int>{
    for (var index = 0; index < next.length; index += 1)
      if ((next[index]['id'] as String? ?? '').isNotEmpty)
        next[index]['id'] as String: index,
  };
  var changed = false;
  for (final row in incoming) {
    final id = row['id'] as String? ?? '';
    if (id.isEmpty) continue;
    final index = indexes[id];
    if (index != null) {
      if (_sameMessage(next[index], row)) continue;
      next.removeAt(index);
      indexes.remove(id);
      for (var i = index; i < next.length; i += 1) {
        indexes[next[i]['id'] as String? ?? ''] = i;
      }
    }
    final insertionIndex = _messageInsertionIndex(next, row);
    next.insert(insertionIndex, row);
    for (var i = insertionIndex; i < next.length; i += 1) {
      indexes[next[i]['id'] as String? ?? ''] = i;
    }
    changed = true;
  }
  return changed ? List.unmodifiable(next) : current;
}

bool _sameMessage(Map<String, dynamic> a, Map<String, dynamic> b) =>
    a['id'] == b['id'] &&
    a['body'] == b['body'] &&
    a['created_at'] == b['created_at'] &&
    a['_delivery_state'] == b['_delivery_state'];

int _messageInsertionIndex(
  List<Map<String, dynamic>> messages,
  Map<String, dynamic> row,
) {
  var low = 0;
  var high = messages.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (_compareMessages(messages[middle], row) <= 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

int _compareMessages(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aTime = DateTime.tryParse(a['created_at'] as String? ?? '');
  final bTime = DateTime.tryParse(b['created_at'] as String? ?? '');
  if (aTime != null && bTime != null) {
    final comparison = aTime.compareTo(bTime);
    if (comparison != 0) return comparison;
  }
  return (a['id'] as String? ?? '').compareTo(b['id'] as String? ?? '');
}

String createChatMessageId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
