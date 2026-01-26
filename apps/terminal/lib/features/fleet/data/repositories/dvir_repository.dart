import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/providers/network_provider.dart';
import '../../domain/models/dvir_report.dart';

part 'dvir_repository.g.dart';

/// Repository for DVIR (Driver Vehicle Inspection Reports)
class DVIRRepository {
  final CoreNetworkClient _client;

  DVIRRepository(this._client);

  /// Fetch all DVIR reports for a vehicle
  Future<Result<List<DVIRReport>>> getInspections(String vehicleId) async {
    return _client.query<List<DVIRReport>>(() async {
      final data = await _client.supabase
          .from('dvir_reports')
          .select('*, profiles!driver_id(full_name)')
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(50);

      return data.map((e) {
        // Flatten the joined profile data
        final profile = e['profiles'] as Map<String, dynamic>?;
        return DVIRReport.fromJson({
          ...e,
          'driver_name': profile?['full_name'],
        });
      }).toList();
    }, operationName: 'getInspections');
  }

  /// Get the most recent DVIR for a vehicle
  Future<Result<DVIRReport?>> getLatestInspection(String vehicleId) async {
    return _client.query<DVIRReport?>(() async {
      final data = await _client.supabase
          .from('dvir_reports')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return data != null ? DVIRReport.fromJson(data) : null;
    }, operationName: 'getLatestInspection');
  }

  /// Create a new DVIR inspection report
  Future<Result<DVIRReport>> createInspection({
    required String vehicleId,
    required DVIRInspectionType inspectionType,
    required bool isSafeToOperate,
    int? odometer,
    List<DVIRDefect> defects = const [],
    String? notes,
    String? driverSignature,
  }) async {
    return _client.query<DVIRReport>(() async {
      final currentUser = _client.supabase.auth.currentUser;

      final data = await _client.supabase
          .from('dvir_reports')
          .insert({
            'vehicle_id': vehicleId,
            'driver_id': currentUser?.id,
            'inspection_type': inspectionType == DVIRInspectionType.preTrip
                ? 'pre_trip'
                : 'post_trip',
            'odometer': odometer,
            'defects_found': defects.isNotEmpty,
            'defects': defects.map((d) => d.toJson()).toList(),
            'is_safe_to_operate': isSafeToOperate,
            'driver_signature': driverSignature,
            'notes': notes,
          })
          .select()
          .single();

      return DVIRReport.fromJson(data);
    }, operationName: 'createInspection');
  }

  /// Mark defects as corrected (mechanic sign-off)
  Future<Result<void>> markDefectCorrected({
    required String reportId,
    String? mechanicSignature,
  }) async {
    return _client.query<void>(() async {
      await _client.supabase
          .from('dvir_reports')
          .update({
            'corrected_at': DateTime.now().toIso8601String(),
            'mechanic_signature': mechanicSignature,
          })
          .eq('id', reportId);
    }, operationName: 'markDefectCorrected');
  }

  /// Get all reports with uncorrected critical defects (fleet-wide)
  Future<Result<List<({DVIRReport report, String vehicleNumber})>>>
  getUncorrectedDefects() async {
    return _client.query<List<({DVIRReport report, String vehicleNumber})>>(
      () async {
        final data = await _client.supabase
            .from('dvir_reports')
            .select('*, vehicles!inner(truck_number)')
            .eq('defects_found', true)
            .eq('is_safe_to_operate', false)
            .isFilter('corrected_at', null)
            .order('created_at', ascending: false);

        return data.map((e) {
          final vehicle = e['vehicles'] as Map<String, dynamic>;
          return (
            report: DVIRReport.fromJson(e),
            vehicleNumber: vehicle['truck_number'] as String? ?? 'Unknown',
          );
        }).toList();
      },
      operationName: 'getUncorrectedDefects',
    );
  }
}

@riverpod
DVIRRepository dvirRepository(Ref ref) {
  return DVIRRepository(ref.watch(coreNetworkClientProvider));
}

@riverpod
Future<List<DVIRReport>> dvirHistory(Ref ref, String vehicleId) async {
  final repo = ref.watch(dvirRepositoryProvider);
  final result = await repo.getInspections(vehicleId);
  return result.fold((failure) => throw failure, (data) => data);
}

@riverpod
Future<DVIRReport?> latestDvir(Ref ref, String vehicleId) async {
  final repo = ref.watch(dvirRepositoryProvider);
  final result = await repo.getLatestInspection(vehicleId);
  return result.fold((failure) => throw failure, (data) => data);
}

@riverpod
Future<List<({DVIRReport report, String vehicleNumber})>> uncorrectedDefects(
  Ref ref,
) async {
  final repo = ref.watch(dvirRepositoryProvider);
  final result = await repo.getUncorrectedDefects();
  return result.fold((failure) => throw failure, (data) => data);
}
