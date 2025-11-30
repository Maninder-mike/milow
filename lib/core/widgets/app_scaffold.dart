import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppScaffold provides a unified layout with consistent background and bottom navigation.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final EdgeInsets? padding;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.appBar,
    this.padding,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF9FAFB);
    return Scaffold(
      backgroundColor: background,
      appBar: appBar,
      body: SafeArea(
        child: Padding(padding: padding ?? EdgeInsets.zero, child: body),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: const Color(0xFF98A2B3),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == 0) context.go('/explore');
          if (index == 1) context.go('/dashboard');
          if (index == 2) context.go('/inbox');
          if (index == 3) context.go('/settings');
        },
      ),
    );
  }
}
