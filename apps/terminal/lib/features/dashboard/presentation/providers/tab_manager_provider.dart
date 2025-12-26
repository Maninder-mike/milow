import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tab_manager_provider.g.dart';

class TabInfo {
  final String id;
  final String title;
  final IconData? icon;
  final Widget child;
  final String? path;

  TabInfo({
    required this.id,
    required this.title,
    required this.child,
    this.icon,
    this.path,
  });
}

class TabManagerState {
  final List<TabInfo> tabs;
  final int selectedIndex;

  const TabManagerState({this.tabs = const [], this.selectedIndex = 0});

  TabManagerState copyWith({List<TabInfo>? tabs, int? selectedIndex}) {
    return TabManagerState(
      tabs: tabs ?? this.tabs,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

@Riverpod(keepAlive: true)
class TabManager extends _$TabManager {
  @override
  TabManagerState build() {
    return const TabManagerState();
  }

  void addTab(TabInfo tab) {
    final index = state.tabs.indexWhere(
      (t) => t.id == tab.id || (t.path != null && t.path == tab.path),
    );
    if (index != -1) {
      // Switch to existing AND update it (vital for content updates on same route)
      final newTabs = [...state.tabs];
      newTabs[index] = tab;
      state = state.copyWith(tabs: newTabs, selectedIndex: index);
    } else {
      // Add new
      state = state.copyWith(
        tabs: [...state.tabs, tab],
        selectedIndex: state.tabs.length, // Index of new item
      );
    }
  }

  void removeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;

    final newTabs = [...state.tabs];
    newTabs.removeAt(index);

    // Adjust selection
    int newIndex = state.selectedIndex;
    if (newIndex >= newTabs.length) {
      newIndex = newTabs.isNotEmpty ? newTabs.length - 1 : 0;
    }

    state = state.copyWith(tabs: newTabs, selectedIndex: newIndex);
  }

  void setSelectedIndex(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }
}
