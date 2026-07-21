import 'package:flutter/foundation.dart';

class ConfigChecker {
  /// Validates that all required configuration values are present at startup.
  /// Throws a descriptive error if any required key is missing or empty.
  static void validate({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    final errors = <String>[];

    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL must be a valid HTTPS URL');
    }
    if (supabaseAnonKey.isEmpty) {
      errors.add('SUPABASE_ANON_KEY must not be empty');
    }

    if (errors.isNotEmpty) {
      debugPrint(
        '❌ Config validation failed:\n${errors.map((e) => '  - $e').join('\n')}',
      );
      throw Exception(
        'Application configuration is invalid. Check your .env file.\n'
        'Missing/Invalid:\n${errors.map((e) => '  - $e').join('\n')}',
      );
    }

    debugPrint('✅ Configuration validated successfully');
  }
}
