import 'package:flutter/material.dart';

import '../constants/app_routes.dart';
import '../theme/app_colors.dart';

class KaamBottomNav extends StatelessWidget {
  const KaamBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavItem('Home', Icons.grid_view_rounded, AppRoutes.dashboard),
    _NavItem('Requests', Icons.ads_click_rounded, AppRoutes.requests),
    _NavItem('Matches', Icons.handshake_rounded, AppRoutes.matches),
    _NavItem('Chat', Icons.chat_bubble_outline_rounded, AppRoutes.chatList),
    _NavItem('Profile', Icons.person_outline_rounded, AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 72,
          selectedIndex: currentIndex,
          indicatorColor: AppColors.primaryPink.withValues(alpha: 0.16),
          onDestinationSelected: (index) {
            if (index == currentIndex) return;
            Navigator.of(context).pushReplacementNamed(_items[index].route);
          },
          destinations: [
            for (final item in _items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon, color: AppColors.primaryPink),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
