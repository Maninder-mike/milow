import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

import '../../../settings/providers/company_provider.dart';

final driverLocationsProvider = StreamProvider<List<DriverLocation>>((ref) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<List<DriverLocation>>.broadcast();

  final companyIdOption = ref.watch(currentCompanyIdProvider);
  final companyId = companyIdOption.value;

  Future<void> fetchLocations() async {
    if (companyId == null) {
      if (!controller.isClosed) controller.add([]);
      return;
    }
    try {
      final data = await supabase
          .from('driver_locations')
          .select('*, profiles:driver_id (full_name, driver_status)')
          .eq('company_id', companyId)
          .order('updated_at', ascending: false);

      final Map<String, DriverLocation> latestPerDriver = {};
      for (var json in data) {
        final loc = DriverLocation.fromJson(json);
        // We know for sure it's per-driver because of unique constraint
        latestPerDriver[loc.driverId] = loc;
      }
      if (!controller.isClosed) {
        controller.add(latestPerDriver.values.toList());
      }
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  // Initial fetch
  fetchLocations();

  // If no companyId, avoid subscribing to everything
  if (companyId == null) {
    ref.onDispose(() => controller.close());
    return controller.stream;
  }

  // Subscribe with company filtering
  final channel = supabase
      .channel('public:driver_locations')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'driver_locations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'company_id',
          value: companyId,
        ),
        callback: (_) => fetchLocations(),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
