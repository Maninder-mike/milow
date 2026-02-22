import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

final driverLocationsProvider = StreamProvider<List<DriverLocation>>((ref) {
  final supabase = Supabase.instance.client;
  final controller = StreamController<List<DriverLocation>>.broadcast();

  Future<void> fetchLocations() async {
    try {
      final data = await supabase
          .from('driver_locations')
          .select()
          .order('timestamp', ascending: false);

      final Map<String, DriverLocation> latestPerDriver = {};
      for (var json in data) {
        final loc = DriverLocation.fromJson(json);
        if (!latestPerDriver.containsKey(loc.driverId)) {
          latestPerDriver[loc.driverId] = loc;
        }
      }
      controller.add(latestPerDriver.values.toList());
    } catch (e) {
      controller.addError(e);
    }
  }

  // Initial fetch
  fetchLocations();

  // Subscribe
  final channel = supabase
      .channel('public:driver_locations')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'driver_locations',
        callback: (_) => fetchLocations(),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
