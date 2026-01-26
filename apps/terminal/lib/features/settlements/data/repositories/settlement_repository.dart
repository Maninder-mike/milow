import 'package:milow_core/milow_core.dart';
import '../../domain/models/driver_pay_config.dart';
import '../../domain/models/driver_settlement.dart';
import '../../domain/models/settlement_item.dart';

class SettlementRepository {
  final CoreNetworkClient _client;

  SettlementRepository(this._client);

  // Pay Configurations
  Future<Result<DriverPayConfig?>> getPayConfig(String driverId) async {
    return _client.query<DriverPayConfig?>(() async {
      final response = await _client.supabase
          .from('driver_pay_configs')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();

      if (response == null) return null;
      return DriverPayConfig.fromJson(response);
    }, operationName: 'getPayConfig');
  }

  Future<Result<void>> savePayConfig(DriverPayConfig config) async {
    return _client.query<void>(() async {
      await _client.supabase.from('driver_pay_configs').upsert(config.toJson());
    }, operationName: 'savePayConfig');
  }

  // Settlements
  Future<Result<List<DriverSettlement>>> fetchSettlements(
    String driverId,
  ) async {
    return _client.query<List<DriverSettlement>>(() async {
      final response = await _client.supabase
          .from('driver_settlements')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DriverSettlement.fromJson(json))
          .toList();
    }, operationName: 'fetchSettlements');
  }

  Future<Result<DriverSettlement>> getSettlementDetails(
    String settlementId,
  ) async {
    return _client.query<DriverSettlement>(() async {
      final response = await _client.supabase
          .from('driver_settlements')
          .select('*, settlement_items(*)')
          .eq('id', settlementId)
          .single();

      final items = (response['settlement_items'] as List)
          .map((itemJson) => SettlementItem.fromJson(itemJson))
          .toList();

      return DriverSettlement.fromJson(response, items);
    }, operationName: 'getSettlementDetails');
  }

  // Auto-Discovery Logic
  Future<Result<List<Map<String, dynamic>>>> discoverUnsettledLoads(
    String driverId,
  ) async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final response = await _client.supabase.rpc(
        'get_unsettled_loads',
        params: {'p_driver_id': driverId},
      );
      return List<Map<String, dynamic>>.from(response);
    }, operationName: 'discoverUnsettledLoads');
  }

  Future<Result<List<Map<String, dynamic>>>> discoverUnsettledFuel(
    String driverId,
  ) async {
    return _client.query<List<Map<String, dynamic>>>(() async {
      final response = await _client.supabase.rpc(
        'get_unsettled_fuel',
        params: {'p_driver_id': driverId},
      );
      return List<Map<String, dynamic>>.from(response);
    }, operationName: 'discoverUnsettledFuel');
  }

  Future<Result<String>> createSettlement(
    DriverSettlement settlement,
    List<SettlementItem> items,
  ) async {
    return _client.query<String>(() async {
      final settlementResponse = await _client.supabase
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
        await _client.supabase.from('settlement_items').insert(itemsJson);
      }

      return settlementId;
    }, operationName: 'createSettlement');
  }

  Future<Result<void>> updateSettlementStatus(
    String settlementId,
    SettlementStatus status,
  ) async {
    return _client.query<void>(() async {
      final statusStr = status == SettlementStatus.voided
          ? 'void'
          : status.name;
      await _client.supabase
          .from('driver_settlements')
          .update({'status': statusStr})
          .eq('id', settlementId);
    }, operationName: 'updateSettlementStatus');
  }
}
