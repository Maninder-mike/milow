import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/trip_repository.dart';
import '../../../../core/providers/network_provider.dart';
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

@riverpod
Stream<int> tripsChangeSignal(Ref ref) {
  final repository = ref.read(tripRepositoryProvider);
  return repository.tripsChangeSignal;
}
