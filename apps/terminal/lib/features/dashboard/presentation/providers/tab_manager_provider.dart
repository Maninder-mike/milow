import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/shared_preferences_provider.dart';

part 'tab_manager_provider.g.dart';

class TabInfo {
  final String id;
  final String title;
  final IconData? icon;
  final Widget? child; // Made optional for persistence
  final String? path;

  TabInfo({
    required this.id,
    required this.title,
    this.child,
    this.icon,
    this.path,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'iconCode': icon?.codePoint,
    'iconFamily': icon?.fontFamily,
    'iconPackage': icon?.fontPackage,
  };

  factory TabInfo.fromJson(Map<String, dynamic> json) => TabInfo(
    id: json['id'],
    title: json['title'],
    path: json['path'],
    icon: json['iconCode'] != null
        ? IconData(
            json['iconCode'],
            fontFamily: json['iconFamily'],
            fontPackage: json['iconPackage'],
          )
        : null,
  );
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
  late SharedPreferences _prefs;
  static const _storageKey = 'active_tabs_v1';

  @override
  TabManagerState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _loadFromPrefs();
  }

  TabManagerState _loadFromPrefs() {
    final stored = _prefs.getString(_storageKey);
    if (stored == null) return const TabManagerState();

    try {
      final List<dynamic> decoded = jsonDecode(stored);
      final tabs = decoded.map((j) => TabInfo.fromJson(j)).toList();
      return TabManagerState(tabs: tabs, selectedIndex: 0);
    } catch (e) {
      debugPrint('Error loading tabs: $e');
      return const TabManagerState();
    }
  }

  Future<void> _saveToPrefs() async {
    final encoded = jsonEncode(state.tabs.map((t) => t.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }

  void addTab(TabInfo tab) {
    if (tab.child == null) return; // Don't add ghost tabs as active

    final index = state.tabs.indexWhere(
      (t) => t.id == tab.id || (t.path != null && t.path == tab.path),
    );

    if (index != -1) {
      final newTabs = [...state.tabs];
      // Keep existing properties but update with new ones (including child)
      newTabs[index] = tab;
      state = state.copyWith(tabs: newTabs, selectedIndex: index);
    } else {
      state = state.copyWith(
        tabs: [...state.tabs, tab],
        selectedIndex: state.tabs.length,
      );
    }
    _saveToPrefs();
  }

  void removeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;

    final newTabs = [...state.tabs];
    newTabs.removeAt(index);

    int newIndex = state.selectedIndex;
    if (newIndex >= newTabs.length) {
      newIndex = newTabs.isNotEmpty ? newTabs.length - 1 : 0;
    }

    state = state.copyWith(tabs: newTabs, selectedIndex: newIndex);
    _saveToPrefs();
  }

  void setSelectedIndex(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }
}
