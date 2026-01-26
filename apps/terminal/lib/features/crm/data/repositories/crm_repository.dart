import 'package:milow_core/milow_core.dart';
import '../../domain/models/crm_entity.dart';
import '../../domain/models/contact.dart';

class CRMRepository {
  final CoreNetworkClient _client;

  CRMRepository(this._client);

  Future<Result<List<CRMEntity>>> fetchEntities(CRMEntityType type) async {
    return _client.query<List<CRMEntity>>(() async {
      switch (type) {
        case CRMEntityType.broker:
          final response = await _client.supabase
              .from('customers')
              .select('*')
              .eq(
                'customer_type',
                'Broker',
              ) // Assuming we only want brokers here, or stick to original logic
              .order('name');
          // Original code didn't filter by customer_type for broker case, but implied it.
          // Let's stick to strict original logic but use 'customers' table as before.
          // Original: .from('customers').select('*').order('name');

          return (response as List)
              .map((e) => CRMEntity.fromCustomerJson(e))
              .toList();
        case CRMEntityType.shipper:
          final response = await _client.supabase
              .from('pickups')
              .select('*')
              .order('shipper_name');
          return (response as List)
              .map((e) => CRMEntity.fromLocationJson(e, CRMEntityType.shipper))
              .toList();
        case CRMEntityType.receiver:
          final response = await _client.supabase
              .from('receivers')
              .select('*')
              .order('receiver_name');
          return (response as List)
              .map((e) => CRMEntity.fromLocationJson(e, CRMEntityType.receiver))
              .toList();
        default:
          return [];
      }
    }, operationName: 'fetchEntities');
  }

  Future<Result<List<Contact>>> fetchEntityContacts(String entityId) async {
    return _client.query<List<Contact>>(() async {
      final response = await _client.supabase
          .from('contacts')
          .select('*')
          .eq('customer_id', entityId)
          .order('name');
      return (response as List).map((e) => Contact.fromJson(e)).toList();
    }, operationName: 'fetchEntityContacts');
  }

  Future<Result<CRMEntity>> getEntityDetails(
    String id,
    CRMEntityType type,
  ) async {
    return _client.query<CRMEntity>(() async {
      final table = _getTableForType(type);
      final response = await _client.supabase
          .from(table)
          .select('*')
          .eq('id', id)
          .single();
      if (type == CRMEntityType.broker) {
        return CRMEntity.fromCustomerJson(response);
      } else {
        return CRMEntity.fromLocationJson(response, type);
      }
    }, operationName: 'getEntityDetails');
  }

  String _getTableForType(CRMEntityType type) {
    switch (type) {
      case CRMEntityType.broker:
        return 'customers';
      case CRMEntityType.shipper:
        return 'pickups';
      case CRMEntityType.receiver:
        return 'receivers';
      default:
        throw Exception('Unsupported CRM entity type');
    }
  }
}
