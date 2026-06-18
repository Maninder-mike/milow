import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:milow_core/milow_core.dart';
import 'package:terminal/features/brokerage/domain/models/manifest.dart';
import 'package:terminal/features/brokerage/domain/models/partner.dart';

class BrokerageRepository {
  BrokerageRepository(this._client, {this.companyId});

  final CoreNetworkClient _client;
  final String? companyId;

  Future<Result<List<Partner>>> fetchPartners() async {
    return _client.query<List<Partner>>(() async {
      AppLogger.debug('Fetching partners...');

      var query = _client.supabase.from('brokerage_partners').select('*');

      if (companyId != null) {
        query = query.eq('company_id', companyId!);
      }

      final response = await query.order('name');

      return (response as List<dynamic>)
          .map((json) => Partner.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchPartners');
  }

  Future<Result<void>> createPartner(Partner partner) async {
    if (companyId == null) return left(const UnauthorizedFailure('Company ID not found.'));
    
    return _client.query<void>(() async {
      AppLogger.info('Creating partner...');
      
      final data = partner.toJson();
      data['company_id'] = companyId;
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');

      await _client.supabase.from('brokerage_partners').insert(data);
      AppLogger.info('Partner created successfully.');
    }, operationName: 'createPartner');
  }

  Future<Result<void>> updatePartner(Partner partner) async {
    if (partner.id.isEmpty) return left(const ValidationFailure('Partner ID required.'));
    
    return _client.query<void>(() async {
      AppLogger.info('Updating partner ${partner.id}...');
      
      final data = partner.toJson();
      data.remove('id');
      data.remove('company_id');
      data.remove('created_at');
      data.remove('updated_at');

      await _client.supabase.from('brokerage_partners').update(data).eq('id', partner.id);
      AppLogger.info('Partner updated successfully.');
    }, operationName: 'updatePartner');
  }

  Future<Result<void>> deletePartner(String id) async {
    if (id.isEmpty) return left(const ValidationFailure('Partner ID required.'));
    
    return _client.query<void>(() async {
      await _client.supabase.from('brokerage_partners').delete().eq('id', id);
    }, operationName: 'deletePartner');
  }

  Future<Result<List<Manifest>>> fetchManifests() async {
    return _client.query<List<Manifest>>(() async {
      AppLogger.debug('Fetching manifests...');

      var query = _client.supabase.from('brokerage_manifests').select('''
          *,
          manifest_items:brokerage_manifest_items(*)
        ''');

      if (companyId != null) {
        query = query.eq('company_id', companyId!);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => Manifest.fromJson(json as Map<String, dynamic>))
          .toList();
    }, operationName: 'fetchManifests');
  }

  Future<Result<void>> createManifest(Manifest manifest) async {
    if (companyId == null) return left(const UnauthorizedFailure('Company ID not found.'));
    
    return _client.query<void>(() async {
      AppLogger.info('Creating manifest...');
      
      final data = manifest.toJson();
      data['company_id'] = companyId;
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');
      data.remove('manifest_items');

      final response = await _client.supabase
          .from('brokerage_manifests')
          .insert(data)
          .select('id')
          .single();

      final newManifestId = response['id'] as String;

      if (manifest.items.isNotEmpty) {
        final itemsData = manifest.items.map((item) {
          final map = item.toJson();
          map['manifest_id'] = newManifestId;
          map.remove('id');
          map.remove('created_at');
          return map;
        }).toList();

        await _client.supabase.from('brokerage_manifest_items').insert(itemsData);
      }

      AppLogger.info('Manifest created successfully ($newManifestId).');
    }, operationName: 'createManifest');
  }

  Future<Result<void>> updateManifest(Manifest manifest) async {
    if (manifest.id.isEmpty) return left(const ValidationFailure('Manifest ID required.'));
    
    return _client.query<void>(() async {
      AppLogger.info('Updating manifest ${manifest.id}...');
      
      final data = manifest.toJson();
      data.remove('id');
      data.remove('company_id');
      data.remove('created_at');
      data.remove('updated_at');
      data.remove('manifest_items');

      await _client.supabase.from('brokerage_manifests').update(data).eq('id', manifest.id);

      await _client.supabase.from('brokerage_manifest_items').delete().eq('manifest_id', manifest.id);

      if (manifest.items.isNotEmpty) {
        final itemsData = manifest.items.map((item) {
          final map = item.toJson();
          map['manifest_id'] = manifest.id;
          map.remove('id');
          map.remove('created_at');
          return map;
        }).toList();

        await _client.supabase.from('brokerage_manifest_items').insert(itemsData);
      }

      AppLogger.info('Manifest updated successfully.');
    }, operationName: 'updateManifest');
  }

  Future<Result<void>> deleteManifest(String id) async {
    if (id.isEmpty) return left(const ValidationFailure('Manifest ID required.'));
    
    return _client.query<void>(() async {
      await _client.supabase.from('brokerage_manifests').delete().eq('id', id);
    }, operationName: 'deleteManifest');
  }
}
