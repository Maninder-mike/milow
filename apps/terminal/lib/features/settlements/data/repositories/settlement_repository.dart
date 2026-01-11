import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/driver_pay_config.dart';
import '../../domain/models/driver_settlement.dart';
import '../../domain/models/settlement_item.dart';

class SettlementRepository {
  final SupabaseClient _client;

  SettlementRepository(this._client);

  // Pay Configurations
  Future<DriverPayConfig?> getPayConfig(String driverId) async {
    final response = await _client
        .from('driver_pay_configs')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle();

    if (response == null) return null;
    return DriverPayConfig.fromJson(response);
  }

  Future<void> savePayConfig(DriverPayConfig config) async {
    await _client.from('driver_pay_configs').upsert(config.toJson());
  }

  // Settlements
  Future<List<DriverSettlement>> fetchSettlements(String driverId) async {
    final response = await _client
        .from('driver_settlements')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => DriverSettlement.fromJson(json))
        .toList();
  }

  Future<DriverSettlement> getSettlementDetails(String settlementId) async {
    final response = await _client
        .from('driver_settlements')
        .select('*, settlement_items(*)')
        .eq('id', settlementId)
        .single();

    final items = (response['settlement_items'] as List)
        .map((itemJson) => SettlementItem.fromJson(itemJson))
        .toList();

    return DriverSettlement.fromJson(response, items);
  }

  // Auto-Discovery Logic
  Future<List<Map<String, dynamic>>> discoverUnsettledLoads(
    String driverId,
  ) async {
    // Finds Delivered loads not yet in any settlement
    final response = await _client.rpc(
      'get_unsettled_loads',
      params: {'p_driver_id': driverId},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> discoverUnsettledFuel(
    String driverId,
  ) async {
    // Finds fuel entries not yet in any settlement
    final response = await _client.rpc(
      'get_unsettled_fuel',
      params: {'p_driver_id': driverId},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> createSettlement(
    DriverSettlement settlement,
    List<SettlementItem> items,
  ) async {
    final settlementResponse = await _client
        .from('driver_settlements')
        .insert(settlement.toJson())
        .select()
        .single();

    final settlementId = settlementResponse['id'] as String;

    // Insert items with the new settlement ID
    final itemsJson = items.map((item) {
      final json = item.toJson();
      json['settlement_id'] = settlementId;
      return json;
    }).toList();

    if (itemsJson.isNotEmpty) {
      await _client.from('settlement_items').insert(itemsJson);
    }

    return settlementId;
  }

  Future<void> updateSettlementStatus(
    String settlementId,
    SettlementStatus status,
  ) async {
    final statusStr = status == SettlementStatus.voided ? 'void' : status.name;
    await _client
        .from('driver_settlements')
        .update({'status': statusStr})
        .eq('id', settlementId);
  }
}
