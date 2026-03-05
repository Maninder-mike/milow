import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

part 'company_drivers_provider.g.dart';

@riverpod
Future<List<UserProfile>> companyDrivers(Ref ref) async {
  final supabase = Supabase.instance.client;

  // Note: RLS should already filter this by company_id
  final data = await supabase
      .from('profiles')
      .select()
      .eq('role', 'driver')
      .order('full_name', ascending: true);

  return (data as List).map((e) => UserProfile.fromJson(e)).toList();
}
