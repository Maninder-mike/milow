import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:animations/animations.dart';
import 'package:milow/features/explore/presentation/pages/explore_page.dart';
import 'package:milow/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:milow/features/inbox/presentation/pages/inbox_page.dart';
import 'package:milow/features/settings/presentation/pages/settings_page.dart';
import 'package:milow/core/utils/responsive_layout.dart';
import 'package:milow/core/widgets/unit_suggestion_overlay.dart';
import 'package:milow/core/providers/unit_suggestion_provider.dart';
import 'package:provider/provider.dart';

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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSuggestionListener();
    });
  }

  void _setupSuggestionListener() {
    if (!mounted) return;
    
    final suggestionProvider = context.read<UnitSuggestionProvider>();
    suggestionProvider.addListener(() {
      if (!mounted) return;
      setState(() {}); // Rebuild stack to show overlay
    });
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
    if (widget.initialIndex != 0) {
      context.go('/dashboard');
    } else {
      final shouldExit = await _showExitConfirmation();
      if (shouldExit == true) {
        await SystemNavigator.pop();
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

  void _onDestinationSelected(int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/inbox');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  List<NavigationRailDestination> get _railDestinations => const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: Text('Explore'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: Text('Inbox'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? context.tokens.scaffoldAltBackground
        : context.tokens.scaffoldAltBackground;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: ResponsiveBuilder(
        builder: (context, size, constraints) {
          final isTabletOrLarger =
              ResponsiveLayout.isTablet(context) ||
              ResponsiveLayout.isDesktop(context);

          return Scaffold(
            backgroundColor: background,
            body: Stack(
              children: [
                Row(
                  children: [
                    if (isTabletOrLarger)
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: _onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        destinations: _railDestinations,
                        backgroundColor: isDark ? null : Colors.white,
                        indicatorColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        elevation: 1,
                      ),
                    Expanded(
                      child: PageTransitionSwitcher(
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
                  ],
                ),
                // Unit Suggestion Overlay
                Consumer<UnitSuggestionProvider>(
                  builder: (context, provider, _) {
                    final country = provider.suggestedCountry;
                    if (country == null) return const SizedBox.shrink();

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: UnitSuggestionOverlay(
                        countryCode: country,
                        onDismiss: () => provider.dismissSuggestion(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
