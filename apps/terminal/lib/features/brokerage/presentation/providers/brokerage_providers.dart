import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:terminal/core/providers/network_provider.dart';
import 'package:terminal/core/providers/profile_provider.dart';
import '../../data/repositories/brokerage_repository.dart';
import '../../domain/models/manifest.dart';
import '../../domain/models/partner.dart';

part 'brokerage_providers.g.dart';

@riverpod
BrokerageRepository brokerageRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  final profile = ref.watch(profileProvider).value;
  return BrokerageRepository(client, companyId: profile?['company_id'] as String?);
}

@riverpod
class BrokerageManifests extends _$BrokerageManifests {
  @override
  FutureOr<List<Manifest>> build() async {
    final repo = ref.watch(brokerageRepositoryProvider);
    final result = await repo.fetchManifests();
    return result.fold(
      (failure) => throw failure,
      (manifests) => manifests,
    );
  }

  Future<void> createManifest(Manifest manifest) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.createManifest(manifest);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }

  Future<void> updateManifest(Manifest manifest) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.updateManifest(manifest);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }

  Future<void> deleteManifest(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.deleteManifest(id);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }
}

@riverpod
class BrokeragePartners extends _$BrokeragePartners {
  @override
  FutureOr<List<Partner>> build() async {
    final repo = ref.watch(brokerageRepositoryProvider);
    final result = await repo.fetchPartners();
    return result.fold(
      (failure) => throw failure,
      (partners) => partners,
    );
  }

  Future<void> createPartner(Partner partner) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.createPartner(partner);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }

  Future<void> updatePartner(Partner partner) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.updatePartner(partner);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }

  Future<void> deletePartner(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(brokerageRepositoryProvider);
    final result = await repo.deletePartner(id);
    result.fold(
      (failure) => state = AsyncError(failure, StackTrace.current),
      (_) => ref.invalidateSelf(),
    );
  }
}
