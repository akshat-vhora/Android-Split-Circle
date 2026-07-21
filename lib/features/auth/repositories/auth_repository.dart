import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/constants/supabase_tables.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/unique_id_generator.dart';

class AuthRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  /// Must match Android `AndroidManifest` intent-filter (`io.supabase.flutter` / `callback`)
  /// and be listed in Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
  static const String emailAuthRedirect = 'io.supabase.flutter://callback';

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final authRes = await _supabase.client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    if (authRes.user == null) {
      throw Exception(
        'Account created! Please check your email to confirm your account before signing in.',
      );
    }
    final uid = authRes.user!.id;
    final sessionExists = _supabase.client.auth.currentSession != null;
    if (!sessionExists) {
      throw Exception(
        'Account created! Please check your email to confirm before signing in.',
      );
    }

    // Check if user already exists in public table (re-registration attempt)
    final existing = await _supabase.client
        .from(SupabaseTables.users)
        .select('uid')
        .eq('uid', uid)
        .maybeSingle();
    if (existing != null) {
      throw Exception(
        'An account with this email already exists. Please sign in instead.',
      );
    }

    String uniqueId;
    do {
      uniqueId = generateUniqueId();
    } while (!await _supabase.isUniqueIdAvailable(uniqueId));
    final userData = {
      'uid': uid,
      'display_name': displayName,
      'email': email,
      'unique_id': uniqueId,
    };
    await _supabase.client.from(SupabaseTables.users).insert(userData);
    return UserModel.fromJson({
      ...userData,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _supabase.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    final serverClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (serverClientId == null || serverClientId.isEmpty) {
      throw Exception(
        'GOOGLE_WEB_CLIENT_ID not configured in .env file. Add your Google Web Client ID from the Supabase Google provider settings.',
      );
    }
    await google.initialize(serverClientId: serverClientId);
    final account = await google.authenticate();
    final auth = account.authentication;
    if (auth.idToken == null) throw Exception('Failed to get Google ID token');
    await _supabase.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
    );
    await _supabase.getCurrentUser();
  }

  Future<String?> checkEmailProvider(String email) async {
    final res = await _supabase.client
        .from(SupabaseTables.users)
        .select('email')
        .eq('email', email.toLowerCase())
        .maybeSingle();
    if (res != null) return 'email';
    return null;
  }

  Future<void> resetPassword(String email) async {
    await _supabase.client.auth.resetPasswordForEmail(
      email,
      redirectTo: emailAuthRedirect,
    );
  }

  Future<void> signOut() async {
    await _supabase.client.auth.signOut();
  }

  bool get isLoggedIn => _supabase.client.auth.currentSession != null;

  String? get currentUid => _supabase.client.auth.currentSession?.user.id;
}
