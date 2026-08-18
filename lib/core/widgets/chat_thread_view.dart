import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

typedef ChatBubbleBuilder = Widget Function(
    BuildContext context, Map<String, dynamic> row);

class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.initialRows,
    required this.bubbleBuilder,
    this.stream,
    this.realtimeFailed = false,
    this.onRetry,
  });

  final List<Map<String, dynamic>> initialRows;
  final Stream<List<Map<String, dynamic>>>? stream;
  final ChatBubbleBuilder bubbleBuilder;
  final bool realtimeFailed;
  final VoidCallback? onRetry;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final scrollController = ScrollController();
  late bool realtimeFailed = widget.realtimeFailed;
  bool showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(ChatThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRows != widget.initialRows) {
      final wasNearBottom = _isNearBottom;
      if (wasNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animated: true),
        );
      } else if (mounted) {
        setState(() => showJumpToLatest = true);
      }
    }
    if (oldWidget.realtimeFailed != widget.realtimeFailed) {
      setState(() => realtimeFailed = widget.realtimeFailed);
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!scrollController.hasClients) return true;
    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels <= 96;
  }

  void _scrollToBottom({bool animated = false}) {
    if (!scrollController.hasClients) return;
    final target = scrollController.position.maxScrollExtent;
    if (animated) {
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      scrollController.jumpTo(target);
    }
    if (mounted) setState(() => showJumpToLatest = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (realtimeFailed) _RealtimeWarning(onRetry: widget.onRetry),
            Expanded(
              child: widget.initialRows.isEmpty
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'No messages yet.',
                        style: AppTextStyles.muted,
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      reverse: false,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: widget.initialRows.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => widget.bubbleBuilder(
                          context, widget.initialRows[index]),
                    ),
            ),
          ],
        ),
        if (showJumpToLatest)
          Positioned(
            right: 4,
            bottom: 18,
            child: FloatingActionButton.extended(
              heroTag: null,
              backgroundColor: AppColors.primaryPink,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              label: const Text('New messages'),
              onPressed: () => _scrollToBottom(animated: true),
            ),
          ),
      ],
    );
  }
}

class _RealtimeWarning extends StatelessWidget {
  const _RealtimeWarning({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Live updates are unavailable. Messages shown below are still loaded.',
              style: AppTextStyles.muted,
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
