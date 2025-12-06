import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/widgets/curved_bottom_nav.dart';
import 'package:milow/features/explore/presentation/pages/explore_page.dart';
import 'package:milow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:milow/features/inbox/presentation/pages/inbox_page.dart';
import 'package:milow/features/settings/presentation/pages/settings_page.dart';
import 'package:milow/l10n/app_localizations.dart';

class TabsShell extends StatefulWidget {
  final int initialIndex;
  const TabsShell({required this.initialIndex, super.key});

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> {
  late PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
    switch (i) {
      case 0:
        context.go('/explore');
        break;
      case 1:
        context.go('/dashboard');
        break;
      case 2:
        context.go('/inbox');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  void _onCenterTap() {
    context.push('/add-entry');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: background,
      extendBody: true, // Allow body to extend behind bottom nav
      body: SafeArea(
        bottom: false, // Bottom nav handles its own padding
        child: PageView(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          children: const [
            ExplorePage(),
            DashboardPage(),
            InboxPage(),
            SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: CurvedBottomNav(
        currentIndex: _index,
        items: [
          CurvedBottomNavItem(
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: AppLocalizations.of(context)!.explore,
          ),
          CurvedBottomNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: AppLocalizations.of(context)!.home,
          ),
          CurvedBottomNavItem(
            icon: Icons.inbox_outlined,
            activeIcon: Icons.inbox,
            label: AppLocalizations.of(context)!.inbox,
          ),
          CurvedBottomNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
        onCenterTap: _onCenterTap,
        onTap: _onTap,
      ),
    );
  }
}
