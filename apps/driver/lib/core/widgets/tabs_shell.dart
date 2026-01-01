import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:animations/animations.dart';
import 'package:milow/features/explore/presentation/pages/explore_page.dart';
import 'package:milow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:milow/features/inbox/presentation/pages/inbox_page.dart';
import 'package:milow/features/settings/presentation/pages/settings_page.dart';

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

  @override
  void didUpdateWidget(TabsShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _index) {
      _index = widget.initialIndex;
      _controller.jumpToPage(_index);
    }
  }

  /// Handle back navigation: go to dashboard from other tabs, confirm exit on dashboard
  Future<void> _handleBackNavigation() async {
    // Use widget.initialIndex to check current tab based on route
    if (widget.initialIndex != 0) {
      // Not on dashboard - navigate to dashboard using go_router
      context.go('/dashboard');
    } else {
      // On dashboard - show exit confirmation
      final shouldExit = await _showExitConfirmation();
      if (shouldExit == true) {
        SystemNavigator.pop();
      }
    }
  }

  Future<bool?> _showExitConfirmation() {
    final tokens = Theme.of(context).extension<DesignTokens>()!;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.shapeXL),
        ),
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit Milow?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? context.tokens.scaffoldAltBackground
        : context.tokens.scaffoldAltBackground;

    return PopScope(
      // Don't allow default pop - we handle it ourselves
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: background,
        body: PageTransitionSwitcher(
          transitionBuilder:
              (
                Widget child,
                Animation<double> primaryAnimation,
                Animation<double> secondaryAnimation,
              ) {
                return FadeThroughTransition(
                  animation: primaryAnimation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
          child: [
            const DashboardPage(),
            const ExplorePage(),
            const InboxPage(),
            const SettingsPage(),
          ][_index],
        ),
      ),
    );
  }
}
