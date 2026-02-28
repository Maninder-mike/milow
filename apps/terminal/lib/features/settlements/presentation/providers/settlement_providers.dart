import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/driver_pay_config.dart';
import '../../domain/models/driver_settlement.dart';
import '../../domain/models/settlement_summary.dart';
import '../../domain/models/settlement_item.dart';
import '../../data/repositories/settlement_repository.dart';
import '../../../../core/providers/network_provider.dart';

part 'settlement_providers.g.dart';

// Fallback provider because of build_runner issues in the cloud environment
final getSettlementSummaryProvider =
    FutureProvider.family<SettlementSummary, String>((ref, driverId) async {
      final settlements = await ref.watch(
        driverSettlementsProvider(driverId).future,
      );
      final unsettledLoads = await ref.watch(
        unsettledLoadsProvider(driverId).future,
      );
      final unsettledFuel = await ref.watch(
        unsettledFuelProvider(driverId).future,
      );

      double totalPending = 0;
      double totalPaid = 0;
      double totalNetPayout = 0;
      int paidCount = 0;

      for (final s in settlements) {
        if (s.status == SettlementStatus.draft ||
            s.status == SettlementStatus.approved) {
          totalPending += s.netPayout;
        } else if (s.status == SettlementStatus.paid) {
          totalPaid += s.netPayout;
          totalNetPayout += s.netPayout;
          paidCount++;
        }
      }

      return SettlementSummary(
        totalPending: totalPending,
        totalPaid: totalPaid,
        averagePayout: paidCount > 0 ? totalNetPayout / paidCount : 0,
        unsettledItemsCount: unsettledLoads.length + unsettledFuel.length,
      );
    });

@riverpod
Future<SettlementSummary> getSettlementSummary(Ref ref, String driverId) async {
  final settlements = await ref.watch(
    driverSettlementsProvider(driverId).future,
  );
  final unsettledLoads = await ref.watch(
    unsettledLoadsProvider(driverId).future,
  );
  final unsettledFuel = await ref.watch(unsettledFuelProvider(driverId).future);

  double totalPending = 0;
  double totalPaid = 0;
  double totalNetPayout = 0;
  int paidCount = 0;

  for (final s in settlements) {
    if (s.status == SettlementStatus.draft ||
        s.status == SettlementStatus.approved) {
      totalPending += s.netPayout;
    } else if (s.status == SettlementStatus.paid) {
      totalPaid += s.netPayout;
      totalNetPayout += s.netPayout;
      paidCount++;
    }
  }

  return SettlementSummary(
    totalPending: totalPending,
    totalPaid: totalPaid,
    averagePayout: paidCount > 0 ? totalNetPayout / paidCount : 0,
    unsettledItemsCount: unsettledLoads.length + unsettledFuel.length,
  );
}

@riverpod
SettlementRepository settlementRepository(Ref ref) {
  return SettlementRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Future<DriverPayConfig?> driverPayConfig(Ref ref, String driverId) async {
  final result = await ref
      .watch(settlementRepositoryProvider)
      .getPayConfig(driverId);
  return result.fold((failure) => throw failure, (config) => config);
}

@riverpod
Future<List<DriverSettlement>> driverSettlements(
  Ref ref,
  String driverId,
) async {
  final result = await ref
      .watch(settlementRepositoryProvider)
      .fetchSettlements(driverId);
  return result.fold((failure) => throw failure, (list) => list);
}

@riverpod
Future<DriverSettlement> settlementDetails(Ref ref, String settlementId) async {
  final result = await ref
      .watch(settlementRepositoryProvider)
      .getSettlementDetails(settlementId);
  return result.fold((failure) => throw failure, (details) => details);
}

@riverpod
Future<List<Map<String, dynamic>>> unsettledLoads(
  Ref ref,
  String driverId,
) async {
  final result = await ref
      .watch(settlementRepositoryProvider)
      .discoverUnsettledLoads(driverId);
  return result.fold((failure) => throw failure, (list) => list);
}

@riverpod
Future<List<Map<String, dynamic>>> unsettledFuel(
  Ref ref,
  String driverId,
) async {
  final result = await ref
      .watch(settlementRepositoryProvider)
      .discoverUnsettledFuel(driverId);
  return result.fold((failure) => throw failure, (list) => list);
}

@riverpod
class SettlementController extends _$SettlementController {
  @override
  FutureOr<void> build() {}

  Future<String> createSettlement({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
    required List<SettlementItem> items,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(settlementRepositoryProvider);

      double totalEarnings = 0;
      double totalDeductions = 0;

      for (final item in items) {
        if (item.amount > 0) {
          totalEarnings += item.amount;
        } else {
          totalDeductions += item.amount.abs();
        }
      }

      final settlement = DriverSettlement(
        id: '', // Will be generated by DB
        driverId: driverId,
        status: SettlementStatus.draft,
        startDate: startDate,
        endDate: endDate,
        totalEarnings: totalEarnings,
        totalDeductions: totalDeductions,
        netPayout: totalEarnings - totalDeductions,
        notes: notes,
      );

      final result = await repository.createSettlement(settlement, items);

      return result.fold(
        (failure) {
          state = AsyncValue.error(failure, StackTrace.current);
          throw failure;
        },
        (id) {
          ref.invalidate(driverSettlementsProvider(driverId));
          state = const AsyncValue.data(null);
          return id;
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateStatus(
    String settlementId,
    String driverId,
    SettlementStatus status,
  ) async {
    state = const AsyncValue.loading();
    try {
      final result = await ref
          .read(settlementRepositoryProvider)
          .updateSettlementStatus(settlementId, status);

      result.fold(
        (failure) {
          state = AsyncValue.error(failure, StackTrace.current);
          throw failure;
        },
        (_) {
          ref.invalidate(driverSettlementsProvider(driverId));
          ref.invalidate(settlementDetailsProvider(settlementId));
          state = const AsyncValue.data(null);
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
