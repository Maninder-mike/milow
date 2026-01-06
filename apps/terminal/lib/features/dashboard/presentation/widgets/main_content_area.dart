import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tab_manager_provider.dart';
import '../../screens/overview_page.dart';

import '../../../drivers/presentation/providers/driver_selection_provider.dart';

class MainContentArea extends ConsumerWidget {
  const MainContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabManagerProvider);
    final tabs = tabState.tabs;
    final selectedIndex = tabState.selectedIndex;
    final selectedDriver = ref.watch(selectedDriverProvider);

    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? theme.resources.solidBackgroundFillColorBase
        : theme
              .resources
              .solidBackgroundFillColorBase; // Or use scaffoldPageColor
    final activeTextColor = theme.resources.textFillColorPrimary;
    final inactiveTextColor = theme.resources.textFillColorSecondary;

    if (tabs.isEmpty) {
      return const OverviewPage();
    }

    return Container(
      color: backgroundColor, // Editor Background
      child: TabView(
        header: Container(),
        onNewPressed: null,
        currentIndex: selectedIndex,
        onChanged: (index) {
          final tab = tabs[index];
          if (tab.path != null) {
            context.go(tab.path!);
          } else {
            ref.read(tabManagerProvider.notifier).setSelectedIndex(index);
          }
        },
        tabs: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;

          String tabText = tab.text;
          if (tab.text == 'Drivers' && selectedDriver != null) {
            tabText = selectedDriver.fullName ?? 'Drivers';
          }

          return Tab(
            text: Text(
              tabText,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
            icon: tab.icon != null
                ? Icon(
                    tab.icon!,
                    size: 14,
                    color: isSelected ? theme.accentColor : inactiveTextColor,
                  )
                : null,
            body: Container(
              color: backgroundColor, // Ensure body is also editor color
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: tab.child,
                ),
              ),
            ),
            onClosed: () {
              ref.read(tabManagerProvider.notifier).removeTab(index);
              Future.microtask(() {
                if (context.mounted) {
                  final newState = ref.read(tabManagerProvider);
                  if (newState.tabs.isNotEmpty) {
                    final newIndex = newState.selectedIndex;
                    if (newIndex >= 0 && newIndex < newState.tabs.length) {
                      final newTab = newState.tabs[newIndex];
                      if (newTab.path != null) {
                        context.go(newTab.path!);
                      }
                    }
                  } else {
                    // All tabs closed.
                  }
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

extension TabInfoDisplay on TabInfo {
  String get text => title.isNotEmpty ? title : 'Untitled';
}
