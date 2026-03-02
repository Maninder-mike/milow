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

  /// Fetches all profiles associated with this company
  Future<List<Map<String, dynamic>>> fetchCompanyMembers(
    String companyId,
  ) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .order('full_name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Removes a driver/user from the company by setting their company_id to null
  Future<void> removeMember(String profileId) async {
    await _client
        .from('profiles')
        .update({'company_id': null})
        .eq('id', profileId);
  }

  /// Updates a member's role within the company
  Future<void> updateMemberRole(String profileId, String newRole) async {
    await _client
        .from('profiles')
        .update({'role': newRole})
        .eq('id', profileId);
  }
}
