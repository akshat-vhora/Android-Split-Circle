import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Supabase project URL.
  /// Loaded from SUPABASE_URL in .env.
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase anonymous (publishable) key.
  /// This key is designed to be public — it is safe to include in client builds.
  /// RLS policies enforce row-level security on the database.
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
