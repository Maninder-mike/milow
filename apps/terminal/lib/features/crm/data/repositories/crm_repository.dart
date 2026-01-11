import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/crm_entity.dart';
import '../../domain/models/contact.dart';

class CRMRepository {
  final SupabaseClient _supabase;

  CRMRepository(this._supabase);

  Future<List<CRMEntity>> fetchEntities(CRMEntityType type) async {
    switch (type) {
      case CRMEntityType.broker:
        final response = await _supabase
            .from('customers')
            .select('*')
            .order('name');
        return (response as List)
            .map((e) => CRMEntity.fromCustomerJson(e))
            .toList();
      case CRMEntityType.shipper:
        final response = await _supabase
            .from('pickups')
            .select('*')
            .order('shipper_name');
        return (response as List)
            .map((e) => CRMEntity.fromLocationJson(e, CRMEntityType.shipper))
            .toList();
      case CRMEntityType.receiver:
        final response = await _supabase
            .from('receivers')
            .select('*')
            .order('receiver_name');
        return (response as List)
            .map((e) => CRMEntity.fromLocationJson(e, CRMEntityType.receiver))
            .toList();
      default:
        return [];
    }
  }

  Future<List<Contact>> fetchEntityContacts(String entityId) async {
    final response = await _supabase
        .from('contacts')
        .select('*')
        .eq('customer_id', entityId)
        .order('name');
    return (response as List).map((e) => Contact.fromJson(e)).toList();
  }

  Future<CRMEntity> getEntityDetails(String id, CRMEntityType type) async {
    final table = _getTableForType(type);
    final response = await _supabase
        .from(table)
        .select('*')
        .eq('id', id)
        .single();
    if (type == CRMEntityType.broker) {
      return CRMEntity.fromCustomerJson(response);
    } else {
      return CRMEntity.fromLocationJson(response, type);
    }
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
