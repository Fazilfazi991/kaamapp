import 'package:flutter/material.dart';

import 'kaam_app_bar.dart';

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.children,
    this.title = 'Kaam',
    this.showBack = false,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 28),
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget> children;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    return Scaffold(
      appBar: KaamAppBar(title: title, showBack: showBack, actions: actions),
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: ListView(
          padding: bottomNavigationBar == null
              ? padding
              : resolvedPadding.copyWith(bottom: resolvedPadding.bottom + 72),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
