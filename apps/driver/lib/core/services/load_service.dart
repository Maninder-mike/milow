import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

/// Service for managing loads in Supabase
class LoadService {
  static SupabaseClient _getClient(SupabaseClient? customClient) {
    return customClient ?? Supabase.instance.client;
  }

  static CoreNetworkClient _getNetworkClient(SupabaseClient client) {
    return CoreNetworkClient(client);
  }

  /// Get all loads assigned to current user
  static Future<List<Load>> getAssignedLoads({
    String? coalesceKey,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final networkClient = _getNetworkClient(client);
    final result = await networkClient.query(
      () async {
        // Query loads joined with stops and customers
        final response = await client
            .from('loads')
            .select('*, stops(*), customers(name)')
            .eq('assigned_driver_id', userId)
            .order('created_at', ascending: false);
        return response as List<dynamic>;
      },
      operationName: 'getAssignedLoads',
      coalesceKey: coalesceKey,
    );

    return result.fold(
      (failure) => throw Exception('Failed to get loads: ${failure.message}'),
      (data) {
        return data.map((json) => Load.fromJson(json)).toList();
      },
    );
  }

  /// Update load status
  static Future<Load> updateLoadStatus(
    String loadId,
    LoadStatus status, {
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from('loads')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loadId)
          .select('*, stops(*), customers(name)')
          .single();

      return Load.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update stop status
  static Future<Stop> updateStopStatus(
    String stopId, {
    required bool isCompleted,
    DateTime? completedAt,
    SupabaseClient? supabaseClient,
  }) async {
    final client = _getClient(supabaseClient);

    try {
      final response = await client
          .from('stops')
          .update({
            'is_completed': isCompleted,
            'completed_at': completedAt?.toIso8601String(),
          })
          .eq('id', stopId)
          .select()
          .single();

      return Stop.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
