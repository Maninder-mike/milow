import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:milow_core/milow_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(Supabase.instance.client);
});

final currentCompanyIdProvider = FutureProvider<String>((ref) async {
  // In a real app, this would come from the auth state or user profile
  // For now, we fetch the first company linked to the user or a default
  // This is a placeholder logic
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('User not logged in');

  // Try to find compnay_id from profile
  final response = await Supabase.instance.client
      .from('profiles')
      .select('company_id')
      .eq('id', user.id)
      .single();

  return response['company_id'] as String;
});

final companyProvider = FutureProvider<Company>((ref) async {
  final repository = ref.watch(companyRepositoryProvider);
  final companyIdAsync = ref.watch(currentCompanyIdProvider);

  return companyIdAsync.when(
    data: (id) => repository.fetchCompany(id),
    loading: () =>
        throw Exception('Loading company ID...'), // Handle gracefully in UI
    error: (err, st) => throw err,
  );
});
