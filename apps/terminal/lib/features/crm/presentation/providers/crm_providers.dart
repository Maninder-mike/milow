import 'package:milow_core/milow_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/crm_repository.dart';
import '../../domain/models/crm_entity.dart';
import '../../domain/models/contact.dart';
import '../../../../core/providers/network_provider.dart';

part 'crm_providers.g.dart';

@riverpod
CRMRepository crmRepository(Ref ref) {
  final client = ref.watch(coreNetworkClientProvider);
  return CRMRepository(client);
}

@riverpod
Future<List<CRMEntity>> crmEntities(Ref ref, CRMEntityType type) async {
  final repository = ref.watch(crmRepositoryProvider);
  final result = await repository.fetchEntities(type);
  return result.fold((f) {
    AppLogger.error('Failed to fetch CRM entities', error: f.message);
    throw f;
  }, (r) => r);
}

@riverpod
Future<CRMEntity> crmEntityDetails(
  Ref ref, {
  required String id,
  required CRMEntityType type,
}) async {
  final repository = ref.watch(crmRepositoryProvider);
  final result = await repository.getEntityDetails(id, type);
  return result.fold((f) {
    AppLogger.error('Failed to fetch CRM entity details', error: f.message);
    throw f;
  }, (r) => r);
}

@riverpod
Future<List<Contact>> crmEntityContacts(Ref ref, String entityId) async {
  final repository = ref.watch(crmRepositoryProvider);
  final result = await repository.fetchEntityContacts(entityId);
  return result.fold((f) {
    AppLogger.error('Failed to fetch CRM entity contacts', error: f.message);
    throw f;
  }, (r) => r);
}
