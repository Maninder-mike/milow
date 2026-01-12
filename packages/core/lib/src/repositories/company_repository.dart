import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';

class CompanyRepository {
  final SupabaseClient _client;

  CompanyRepository(this._client);

  Future<Company> fetchCompany(String companyId) async {
    final response = await _client
        .from('companies')
        .select()
        .eq('id', companyId)
        .single();

    return Company.fromJson(response);
  }

  Future<void> updateSettings(
    String companyId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('companies').update(updates).eq('id', companyId);
  }

  Future<void> updateApiKeys(String companyId, List<dynamic> apiKeys) async {
    await _client
        .from('companies')
        .update({'api_keys': apiKeys})
        .eq('id', companyId);
  }
}
