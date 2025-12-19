// ignore_for_file: avoid_print

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:milow_core/milow_core.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;

    print('Checking for "companies" table...');

    // Try to fetch one row from companies
    try {
      final response = await supabase.from('companies').select().limit(1);

      print('Table "companies" FOUND.');
      if (response.isNotEmpty) {
        print('Columns: ${response.first.keys.join(', ')}');
      } else {
        print('Table is empty.');
      }
    } catch (e) {
      print('Table "companies" query failed: $e');
    }
  } catch (e) {
    print('Init Error: $e');
  }
}
