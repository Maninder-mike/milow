import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/l10n/app_localizations.dart';

/// AppScaffold provides a unified layout with consistent background and bottom navigation.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final PreferredSizeWidget? appBar;
  final EdgeInsets? padding;
  final Widget? floatingActionButton;

  const AppScaffold({
    required this.body,
    required this.currentIndex,
    super.key,
    this.appBar,
    this.padding,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: appBar,
      body: SafeArea(
        child: Padding(padding: padding ?? EdgeInsets.zero, child: body),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)?.dashboard ?? 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_outlined),
            activeIcon: const Icon(Icons.explore),
            label: AppLocalizations.of(context)?.explore ?? 'Explore',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.mail_outline),
            activeIcon: const Icon(Icons.mail),
            label: AppLocalizations.of(context)?.inbox ?? 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)?.settings ?? 'Settings',
          ),
        ],
        onTap: (index) {
          if (index == 0) context.go('/dashboard');
          if (index == 1) context.go('/explore');
          if (index == 2) context.go('/inbox');
          if (index == 3) context.go('/settings');
        },
      ),
    );
  }
}
