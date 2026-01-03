import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration constants.
///
/// Supports two modes:
/// - **Development**: Reads from `.env` file via dotenv
/// - **Production**: Reads from compile-time `--dart-define` flags
///
/// Build for production with:
/// ```bash
/// flutter build macos \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_anon_key
/// ```
class SupabaseConstants {
  // Compile-time constants from --dart-define (production)
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Returns Supabase URL, preferring dart-define over dotenv.
  static String get supabaseUrl => _envUrl.isNotEmpty
      ? _envUrl
      : dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '';

  /// Returns Supabase Anon Key, preferring dart-define over dotenv.
  static String get supabaseAnonKey => _envKey.isNotEmpty
      ? _envKey
      : dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '';
}
