import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tab_manager_provider.dart';
import '../../screens/overview_page.dart';

class MainContentArea extends ConsumerWidget {
  const MainContentArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(tabManagerProvider);
    final tabs = tabState.tabs;
    final selectedIndex = tabState.selectedIndex;

    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);
    final activeTextColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF333333);
    final inactiveTextColor = isDark
        ? const Color(0xFF969696)
        : const Color(0xFF616161);

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

          return Tab(
            text: Text(
              tab.text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
            icon: tab.icon != null
                ? Icon(
                    tab.icon!,
                    size: 14,
                    color: isSelected
                        ? const Color(0xFF61DAFB)
                        : inactiveTextColor,
                  )
                : null,
            body: Container(
              color: backgroundColor, // Ensure body is also editor color
              child: tab.child,
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
                    // All tabs closed. Maybe navigate to a 'dashboard' route that shows nothing?
                    // Or just stay on current route but show "No tabs"?
                    // The empty state widget below handles the visual.
                    // URL might stay as the last visited page.
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
