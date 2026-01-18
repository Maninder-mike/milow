import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/shared_preferences_provider.dart';

part 'dashboard_config_provider.g.dart';

enum DashboardWidgetType {
  activeLoads,
  revenueMTD,
  fleetHealth,
  awaitingDispatch,
  loadVolumeTrend,
  criticalAlerts,
  operationalMap,
}

@riverpod
class DashboardConfig extends _$DashboardConfig {
  static const _storageKey = 'dashboard_widgets_v1';

  @override
  List<DashboardWidgetType> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_storageKey);

    if (saved != null) {
      try {
        final List<dynamic> decoded = jsonDecode(saved);
        return decoded
            .map(
              (e) => DashboardWidgetType.values.firstWhere((t) => t.name == e),
            )
            .toList();
      } catch (_) {
        return _defaultWidgets;
      }
    }
    return _defaultWidgets;
  }

  static const _defaultWidgets = [
    DashboardWidgetType.activeLoads,
    DashboardWidgetType.revenueMTD,
    DashboardWidgetType.fleetHealth,
    DashboardWidgetType.awaitingDispatch,
    DashboardWidgetType.loadVolumeTrend,
    DashboardWidgetType.criticalAlerts,
  ];

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = [...state];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
    await _save();
  }

  Future<void> addWidget(DashboardWidgetType type) async {
    if (state.contains(type)) return;
    state = [...state, type];
    await _save();
  }

  Future<void> removeWidget(DashboardWidgetType type) async {
    state = state.where((t) => t != type).toList();
    await _save();
  }

  Future<void> reset() async {
    state = _defaultWidgets;
    await _save();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final encoded = jsonEncode(state.map((e) => e.name).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
