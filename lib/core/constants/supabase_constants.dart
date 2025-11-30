import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConstants {
  static String get supabaseUrl => dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '';
}
