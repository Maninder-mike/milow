import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/crm_repository.dart';
import '../../domain/models/crm_entity.dart';
import '../../domain/models/contact.dart';

part 'crm_providers.g.dart';

@riverpod
CRMRepository crmRepository(Ref ref) {
  return CRMRepository(Supabase.instance.client);
}

@riverpod
Future<List<CRMEntity>> crmEntities(Ref ref, CRMEntityType type) {
  final repository = ref.watch(crmRepositoryProvider);
  return repository.fetchEntities(type);
}

@riverpod
Future<CRMEntity> crmEntityDetails(
  Ref ref, {
  required String id,
  required CRMEntityType type,
}) {
  final repository = ref.watch(crmRepositoryProvider);
  return repository.getEntityDetails(id, type);
}

@riverpod
Future<List<Contact>> crmEntityContacts(Ref ref, String entityId) {
  final repository = ref.watch(crmRepositoryProvider);
  return repository.fetchEntityContacts(entityId);
}
