import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaam_perfect_match/core/chat/chat_conversation_controller.dart';
import 'package:kaam_perfect_match/core/widgets/chat_conversation_view.dart';

void main() {
  group('chat send acknowledgement and reconciliation', () {
    test('1. successful insert marks message sent', () async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.controller.send('Hello');

      expect(_delivery(fixture.controller), ChatDeliveryState.sent.name);
    });

    test('2. successful insert never shows failed', () async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.controller.send('Hello');

      expect(
        fixture.controller.messages.single['_delivery_state'],
        isNot(ChatDeliveryState.failed.name),
      );
    });

    test('3. realtime echo reconciles optimistic message', () async {
      final gateway = _FakeGateway()
        ..results.add(const ChatSendResult.uncertain());
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();
      await fixture.controller.send('Hello');
      final id = fixture.controller.messages.single['id'] as String;

      gateway.emit([gateway.row(id, 'Hello')]);

      expect(_delivery(fixture.controller), ChatDeliveryState.sent.name);
      expect(fixture.controller.messages.single['_optimistic'], isFalse);
    });

    test('4. realtime echo does not create a duplicate', () async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.controller.send('Hello');
      final row = fixture.controller.messages.single;

      fixture.gateway.emit([row, row]);

      expect(fixture.controller.messages, hasLength(1));
    });

    test('5. rapid repeated send taps create one message', () async {
      final gateway = _FakeGateway()..sendGate = Completer<void>();
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();

      final first = fixture.controller.send('Hello');
      final secondAccepted = await fixture.controller.send('Hello');
      gateway.sendGate!.complete();
      await first;

      expect(secondAccepted, isFalse);
      expect(gateway.sentIds, hasLength(1));
      expect(fixture.controller.messages, hasLength(1));
    });

    test('6. retry after real failure creates one logical message', () async {
      final gateway = _FakeGateway()
        ..results.add(const ChatSendResult.retryableFailure());
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();
      await fixture.controller.send('Hello');
      final id = fixture.controller.messages.single['id'] as String;

      await fixture.controller.retry(id);

      expect(gateway.sentIds, [id, id]);
      expect(fixture.controller.messages, hasLength(1));
      expect(_delivery(fixture.controller), ChatDeliveryState.sent.name);
    });

    test('7. uncertain timeout is not immediately a definite failure',
        () async {
      final gateway = _FakeGateway()
        ..results.add(const ChatSendResult.uncertain());
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();

      await fixture.controller.send('Hello');

      expect(_delivery(fixture.controller), ChatDeliveryState.checking.name);
    });

    test('8. readback can resolve an uncertain send', () async {
      final gateway = _FakeGateway()
        ..results.add(const ChatSendResult.uncertain())
        ..readbackCurrentAttempt = true;
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();

      await fixture.controller.send('Hello');

      expect(_delivery(fixture.controller), ChatDeliveryState.sent.name);
    });

    test('9. candidate and employer use the same shared send rules', () {
      final candidate = File(
        'lib/features/candidate/chat/private_chat_screen.dart',
      ).readAsStringSync();
      final employer = File(
        'lib/features/employer/chat/employer_chat_screens.dart',
      ).readAsStringSync();

      expect(candidate, contains('ChatConversationView('));
      expect(employer, contains('ChatConversationView('));
      expect(candidate, isNot(contains('repository.sendMessage(')));
      expect(employer, isNot(contains('repository.sendMessage(')));
    });

    testWidgets('10. chat shows loading before authorization resolves',
        (tester) async {
      final gateway = _FakeGateway()..accessGate = Completer<bool>();
      await _pumpConversation(tester, gateway);

      expect(find.text('Loading conversation…'), findsOneWidget);
      gateway.accessGate!.complete(true);
      await tester.pump();
    });

    testWidgets('11. unavailable is absent during normal loading',
        (tester) async {
      final gateway = _FakeGateway()..accessGate = Completer<bool>();
      await _pumpConversation(tester, gateway);

      expect(find.text('Chat is not available for this match.'), findsNothing);
      gateway.accessGate!.complete(true);
      await tester.pump();
    });

    testWidgets('12. unavailable appears only after conclusive denial',
        (tester) async {
      final gateway = _FakeGateway()..accessGate = Completer<bool>();
      await _pumpConversation(tester, gateway);
      gateway.accessGate!.complete(false);
      await tester.pump();

      expect(
        find.text('Chat is not available for this match.'),
        findsOneWidget,
      );
    });

    test('13. initial messages remain visible if realtime fails', () async {
      final gateway = _FakeGateway()
        ..storedRows.add(_serverRow('history', 'Previous message'));
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();

      gateway.failRealtime();

      expect(fixture.controller.realtimeFailed, isTrue);
      expect(fixture.controller.messages.single['body'], 'Previous message');
    });

    test('14. send refreshes conversation when realtime is unavailable',
        () async {
      final fixture = _Fixture();
      await fixture.initialize();
      fixture.gateway.failRealtime();

      await fixture.controller.send('Hello');

      expect(fixture.gateway.loadCalls, greaterThanOrEqualTo(2));
      expect(_delivery(fixture.controller), ChatDeliveryState.sent.name);
    });

    test('15. empty messages remain blocked', () async {
      final fixture = _Fixture();
      await fixture.initialize();

      expect(await fixture.controller.send('   '), isFalse);
      expect(fixture.gateway.sentIds, isEmpty);
    });

    test('16. message history persists after restart simulation', () async {
      final gateway = _FakeGateway();
      final first = _Fixture(gateway: gateway);
      await first.initialize();
      await first.controller.send('Persist me');
      first.controller.dispose();

      final restarted = _Fixture(gateway: gateway);
      await restarted.initialize();

      expect(restarted.controller.messages, hasLength(1));
      expect(restarted.controller.messages.single['body'], 'Persist me');
    });

    test('17. raw backend errors are not shown', () async {
      final gateway = _FakeGateway()
        ..results.add(const ChatSendResult.permanentFailure());
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();
      await fixture.controller.send('Hello');
      final viewSource = File(
        'lib/core/widgets/chat_conversation_view.dart',
      ).readAsStringSync();

      expect(_delivery(fixture.controller), ChatDeliveryState.failed.name);
      expect(viewSource, contains('Message not sent. Tap to retry.'));
      expect(viewSource, isNot(contains('PostgrestException')));
      expect(viewSource, isNot(contains('error.toString()')));
    });

    test('18. duplicate realtime events are ignored', () async {
      final gateway = _FakeGateway();
      final fixture = _Fixture(gateway: gateway);
      await fixture.initialize();
      final row = gateway.row('same-id', 'Hello');

      gateway.emit([row]);
      gateway.emit([row]);

      expect(fixture.controller.messages, hasLength(1));
    });
  });
}

class _Fixture {
  _Fixture({_FakeGateway? gateway}) : gateway = gateway ?? _FakeGateway() {
    controller = ChatConversationController(
      gateway: this.gateway,
      matchId: 'match-1',
      senderId: 'sender-1',
      createMessageId: () => 'message-${this.gateway.sentIds.length + 1}',
    );
  }

  final _FakeGateway gateway;
  late final ChatConversationController controller;

  Future<void> initialize() => controller.initialize();
}

class _FakeGateway implements ChatGateway {
  final storedRows = <Map<String, dynamic>>[];
  final results = <ChatSendResult>[];
  final sentIds = <String>[];
  final realtime = StreamController<List<Map<String, dynamic>>>.broadcast(
    sync: true,
  );
  Completer<bool>? accessGate;
  Completer<void>? sendGate;
  bool readbackCurrentAttempt = false;
  int loadCalls = 0;
  String? lastBody;

  @override
  Future<bool> resolveAccess(String matchId) async {
    return accessGate?.future ?? true;
  }

  @override
  Future<List<Map<String, dynamic>>> loadMessages(String matchId) async {
    loadCalls += 1;
    return storedRows.map((row) => {...row}).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> realtimeMessages(String matchId) =>
      realtime.stream;

  @override
  Future<ChatSendResult> sendMessage({
    required String matchId,
    required String body,
    required String messageId,
  }) async {
    sentIds.add(messageId);
    lastBody = body;
    await sendGate?.future;
    final result = results.isEmpty
        ? ChatSendResult.success(row(messageId, body))
        : results.removeAt(0);
    if (result.outcome == ChatSendOutcome.success) {
      final acknowledged = result.message ?? row(messageId, body);
      if (!storedRows.any((item) => item['id'] == messageId)) {
        storedRows.add(acknowledged);
      }
      return ChatSendResult.success(acknowledged);
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>?> findMessageById({
    required String matchId,
    required String messageId,
  }) async {
    if (readbackCurrentAttempt) {
      final acknowledged = row(messageId, lastBody ?? '');
      storedRows.add(acknowledged);
      return acknowledged;
    }
    for (final row in storedRows) {
      if (row['id'] == messageId) return {...row};
    }
    return null;
  }

  Map<String, dynamic> row(String id, String body) => _serverRow(id, body);

  void emit(List<Map<String, dynamic>> rows) => realtime.add(rows);

  void failRealtime() => realtime.addError(StateError('channel unavailable'));
}

Map<String, dynamic> _serverRow(String id, String body) => {
      'id': id,
      'match_id': 'match-1',
      'sender_id': 'sender-1',
      'body': body,
      'is_read': false,
      'created_at': '2026-07-31T12:00:00.000Z',
    };

String? _delivery(ChatConversationController controller) =>
    controller.messages.single['_delivery_state'] as String?;

Future<void> _pumpConversation(
  WidgetTester tester,
  _FakeGateway gateway,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatConversationView(
          gateway: gateway,
          matchId: 'match-1',
          senderId: 'sender-1',
          composerHint: 'Write your message',
          bubbleBuilder: (context, row) => Text(row['body'] as String? ?? ''),
        ),
      ),
    ),
  );
}
