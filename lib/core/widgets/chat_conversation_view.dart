import 'package:flutter/material.dart';

import '../chat/chat_conversation_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'chat_thread_view.dart';
import 'secondary_button.dart';

typedef ConversationBubbleBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> row,
);

class ChatConversationView extends StatefulWidget {
  const ChatConversationView({
    super.key,
    required this.gateway,
    required this.matchId,
    required this.senderId,
    required this.bubbleBuilder,
    required this.composerHint,
  });

  final ChatGateway gateway;
  final String matchId;
  final String senderId;
  final ConversationBubbleBuilder bubbleBuilder;
  final String composerHint;

  @override
  State<ChatConversationView> createState() => _ChatConversationViewState();
}

class _ChatConversationViewState extends State<ChatConversationView> {
  late ChatConversationController conversation;

  @override
  void initState() {
    super.initState();
    _createConversation();
  }

  @override
  void didUpdateWidget(ChatConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId ||
        oldWidget.senderId != widget.senderId ||
        oldWidget.gateway != widget.gateway) {
      conversation.dispose();
      _createConversation();
    }
  }

  void _createConversation() {
    conversation = ChatConversationController(
      gateway: widget.gateway,
      matchId: widget.matchId,
      senderId: widget.senderId,
    );
    conversation.initialize();
  }

  @override
  void dispose() {
    conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: conversation,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(child: _buildConversation()),
            if (conversation.state == ChatConversationState.ready) ...[
              const SizedBox(height: 12),
              _ChatComposer(
                hintText: widget.composerHint,
                sendInProgress: conversation.sendInProgress,
                onSend: conversation.send,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildConversation() {
    switch (conversation.state) {
      case ChatConversationState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading conversation…', style: AppTextStyles.muted),
            ],
          ),
        );
      case ChatConversationState.unavailable:
        return const Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Chat is not available for this match.',
            style: AppTextStyles.body,
          ),
        );
      case ChatConversationState.loadFailed:
        return Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load chat right now. Please try again.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Retry',
                onPressed: conversation.initialize,
              ),
            ],
          ),
        );
      case ChatConversationState.ready:
        return ChatThreadView(
          initialRows: conversation.messages,
          realtimeFailed: conversation.realtimeFailed,
          onRetry: conversation.refresh,
          bubbleBuilder: (context, row) => _DeliveryBubble(
            row: row,
            isMine: row['sender_id'] == widget.senderId,
            bubble: widget.bubbleBuilder(context, row),
            onRetry: () => conversation.retry(row['id'] as String? ?? ''),
          ),
        );
    }
  }
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.hintText,
    required this.sendInProgress,
    required this.onSend,
  });

  final String hintText;
  final bool sendInProgress;
  final Future<bool> Function(String body) onSend;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() => setState(() {});

  Future<void> _send() async {
    final accepted = await widget.onSend(controller.text);
    if (accepted && mounted) controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !widget.sendInProgress && controller.text.trim().isNotEmpty;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        suffixIcon: IconButton(
          icon: widget.sendInProgress
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, color: AppColors.primaryPink),
          onPressed: canSend ? _send : null,
        ),
      ),
    );
  }
}

class _DeliveryBubble extends StatelessWidget {
  const _DeliveryBubble({
    required this.row,
    required this.isMine,
    required this.bubble,
    required this.onRetry,
  });

  final Map<String, dynamic> row;
  final bool isMine;
  final Widget bubble;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final state = row['_delivery_state'] as String?;
    final label = switch (state) {
      'sending' => 'Sending…',
      'checking' => 'Checking…',
      'failed' => 'Message not sent. Tap to retry.',
      _ => null,
    };
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        if (isMine && label != null)
          state == 'failed'
              ? TextButton(onPressed: onRetry, child: Text(label))
              : Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4),
                  child: Text(label, style: AppTextStyles.muted),
                ),
      ],
    );
  }
}
