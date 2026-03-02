import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/trip_repository.dart';
import '../../../../core/providers/network_provider.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../settings/providers/company_provider.dart';

part 'trip_providers.g.dart';

/// Repository Provider
@riverpod
TripRepository tripRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  final companyIdOption = ref.watch(currentCompanyIdProvider);
  final companyId = companyIdOption.value;
  return TripRepository(client, companyId: companyId);
}

/// Signal that emits when the 'driver_trips' table changes
@riverpod
Stream<int> tripsChangeSignal(Ref ref) {
  final controller = StreamController<int>();
  int counter = 0;

  final supabase = ref.watch(supabaseClientProvider);
  final companyIdOption = ref.watch(currentCompanyIdProvider);
  final companyId = companyIdOption.value;

  if (companyId == null) {
    return const Stream.empty();
  }

  final channel = supabase.channel('public:driver_trips:$companyId');

  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'driver_trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'company_id',
          value: companyId,
        ),
        callback: (payload) {
          counter++;
          if (!controller.isClosed) controller.add(counter);
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}
