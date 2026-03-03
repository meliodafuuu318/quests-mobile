import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/pusher_service.dart';
import '../theme/app_theme.dart';
import 'feed/feed_screen.dart';
import 'friends/friends_screen.dart';
import 'profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _idx = 0;

  final _pages = const [FeedScreen(), FriendsScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    // Fetch initial unread count so the bell badge is correct on app start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncUnread());
  }

  Future<void> _syncUnread() async {
    try {
      final res = await ApiService.getNotifications();
      if (res['error'] == false && mounted) {
        final unread = res['results']?['unread_count'];
        if (unread != null) {
          PusherService.instance.setUnreadCount(
            int.tryParse(unread.toString()) ?? 0,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'FEED', index: 0, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'GUILD', index: 1, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'PROFILE', index: 2, current: _idx, onTap: (i) => setState(() => _idx = i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final Function(int) onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.goldDim : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? activeIcon : icon, color: active ? AppTheme.gold : AppTheme.textMuted, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: active ? AppTheme.gold : AppTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ]),
      ),
    );
  }
}