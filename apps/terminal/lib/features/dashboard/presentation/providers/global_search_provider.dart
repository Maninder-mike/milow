import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:terminal/features/dashboard/domain/models/search_result.dart';

// Import providers from other features
import 'package:terminal/features/dispatch/presentation/providers/load_providers.dart';
import 'package:terminal/features/users/data/user_repository_provider.dart';
import 'package:terminal/features/dashboard/services/vehicle_service.dart';
import 'package:milow_core/milow_core.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as sys_icons;

part 'global_search_provider.g.dart';

@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String query) => state = query;
}

@riverpod
Future<List<SearchResult>> searchResults(Ref ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return [];

  final List<SearchResult> results = [];

  // 1. Actions & Navigation (Universal commands)
  final commands = [
    const SearchResult(
      title: 'Keyboard Shortcuts',
      subtitle: 'View app shortcuts reference',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.keyboard_24_regular,
      data: 'open_shortcuts',
    ),
    const SearchResult(
      title: 'Report Issue',
      subtitle: 'Submit a bug or feature request',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.warning_24_regular,
      data: 'open_report_issue',
    ),
    const SearchResult(
      title: 'Help & Documentation',
      subtitle: 'Open Milow Terminal wiki',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.question_circle_24_regular,
      data: 'open_help',
    ),
    const SearchResult(
      title: 'Go to Drivers',
      subtitle: 'Manage fleet drivers',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.people_team_24_regular,
      route: '/drivers',
    ),
    const SearchResult(
      title: 'Go to Vehicles',
      subtitle: 'Manage truck fleet',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.vehicle_truck_24_regular,
      route: '/vehicles',
    ),
    const SearchResult(
      title: 'Go to Highway Dispatch',
      subtitle: 'Manage loads and dispatching',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.box_24_regular,
      route: '/highway-dispatch',
    ),
    const SearchResult(
      title: 'Create New Load',
      subtitle: 'Open load entry form',
      type: SearchResultType.action,
      icon: sys_icons.FluentIcons.add_24_regular,
      route: '/highway-dispatch', // Page handles state
    ),
  ];

  for (final cmd in commands) {
    if (cmd.title.toLowerCase().contains(query) ||
        cmd.subtitle.toLowerCase().contains(query)) {
      results.add(cmd);
    }
  }

  // 2. Search Loads
  try {
    final loadsAsync = ref.watch(loadsListProvider);
    loadsAsync.whenData((loads) {
      final filtered = loads.where(
        (l) =>
            l.loadReference.toLowerCase().contains(query) ||
            l.pickup.companyName.toLowerCase().contains(query) ||
            l.delivery.companyName.toLowerCase().contains(query),
      );

      results.addAll(
        filtered
            .take(5)
            .map(
              (l) => SearchResult(
                title: 'Load: ${l.loadReference}',
                subtitle:
                    '${l.pickup.city}, ${l.pickup.state} -> ${l.delivery.city}, ${l.delivery.state}',
                type: SearchResultType.load,
                data: l,
                route: '/highway-dispatch',
                icon: sys_icons.FluentIcons.box_24_regular,
              ),
            ),
      );
    });
  } catch (_) {}

  // 3. Search Drivers
  try {
    final usersAsync = ref.watch(usersProvider);
    usersAsync.whenData((users) {
      final filtered = users.where(
        (u) =>
            u.role == UserRole.driver &&
            (u.fullName?.toLowerCase().contains(query) ?? false),
      );

      results.addAll(
        filtered
            .take(3)
            .map(
              (u) => SearchResult(
                title: 'Driver: ${u.fullName}',
                subtitle: u.email ?? 'No email',
                type: SearchResultType.driver,
                data: u,
                route: '/drivers',
                icon: sys_icons.FluentIcons.person_24_regular,
              ),
            ),
      );
    });
  } catch (_) {}

  // 4. Search Fleet
  try {
    final vehiclesAsync = ref.watch(vehiclesListProvider);
    vehiclesAsync.whenData((vehicles) {
      final filtered = vehicles.where(
        (v) =>
            (v['truck_number'] as String?)?.toLowerCase().contains(query) ==
                true ||
            (v['license_plate'] as String?)?.toLowerCase().contains(query) ==
                true,
      );

      results.addAll(
        filtered
            .take(3)
            .map(
              (v) => SearchResult(
                title: 'Vehicle: ${v['truck_number']}',
                subtitle: '${v['vehicle_type']} • ${v['status']}',
                type: SearchResultType.vehicle,
                data: v,
                route: '/vehicles',
                icon: sys_icons.FluentIcons.vehicle_truck_24_regular,
              ),
            ),
      );
    });
  } catch (_) {}

  return results;
}
