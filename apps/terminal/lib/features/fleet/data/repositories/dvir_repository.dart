import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/models/dvir_report.dart';

part 'dvir_repository.g.dart';

/// Repository for DVIR (Driver Vehicle Inspection Reports)
class DVIRRepository {
  final SupabaseClient _client;

  DVIRRepository(this._client);

  /// Fetch all DVIR reports for a vehicle
  Future<List<DVIRReport>> getInspections(String vehicleId) async {
    final data = await _client
        .from('dvir_reports')
        .select('*, profiles!driver_id(full_name)')
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false)
        .limit(50);

    return data.map((e) {
      // Flatten the joined profile data
      final profile = e['profiles'] as Map<String, dynamic>?;
      return DVIRReport.fromJson({...e, 'driver_name': profile?['full_name']});
    }).toList();
  }

  /// Get the most recent DVIR for a vehicle
  Future<DVIRReport?> getLatestInspection(String vehicleId) async {
    final data = await _client
        .from('dvir_reports')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data != null ? DVIRReport.fromJson(data) : null;
  }

  /// Create a new DVIR inspection report
  Future<DVIRReport> createInspection({
    required String vehicleId,
    required DVIRInspectionType inspectionType,
    required bool isSafeToOperate,
    int? odometer,
    List<DVIRDefect> defects = const [],
    String? notes,
    String? driverSignature,
  }) async {
    final currentUser = _client.auth.currentUser;

    final data = await _client
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
  }

  /// Mark defects as corrected (mechanic sign-off)
  Future<void> markDefectCorrected({
    required String reportId,
    String? mechanicSignature,
  }) async {
    await _client
        .from('dvir_reports')
        .update({
          'corrected_at': DateTime.now().toIso8601String(),
          'mechanic_signature': mechanicSignature,
        })
        .eq('id', reportId);
  }

  /// Get all reports with uncorrected critical defects (fleet-wide)
  Future<List<({DVIRReport report, String vehicleNumber})>>
  getUncorrectedDefects() async {
    final data = await _client
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
  }
}

@riverpod
DVIRRepository dvirRepository(Ref ref) {
  return DVIRRepository(ref.read(supabaseClientProvider));
}

@riverpod
Future<List<DVIRReport>> dvirHistory(Ref ref, String vehicleId) async {
  final repo = ref.watch(dvirRepositoryProvider);
  return repo.getInspections(vehicleId);
}

@riverpod
Future<DVIRReport?> latestDvir(Ref ref, String vehicleId) async {
  final repo = ref.watch(dvirRepositoryProvider);
  return repo.getLatestInspection(vehicleId);
}

@riverpod
Future<List<({DVIRReport report, String vehicleNumber})>> uncorrectedDefects(
  Ref ref,
) async {
  final repo = ref.watch(dvirRepositoryProvider);
  return repo.getUncorrectedDefects();
}
