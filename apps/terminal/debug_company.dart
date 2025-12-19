// ignore_for_file: avoid_print

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart'; // Assuming constants here

Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;

    print('Attempting to fetch company_details schema...');

    // Try to fetch one row
    final response = await supabase.from('company_details').select().limit(1);

    if (response.isNotEmpty) {
      print('Columns found: ${response.first.keys.join(', ')}');
      print('First row: ${response.first}');
    } else {
      print('Table exists but empty. Can verify existence at least.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
