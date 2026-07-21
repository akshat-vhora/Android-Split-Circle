import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../services/cache_manager.dart';
import '../../../shared/constants/cache_durations.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Derives the current user ID from the auth state stream.
/// When the stream emits a new event (login/logout/token refresh),
/// this provider emits a new value, cascading invalidation to dependents.
final currentUserUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState is AsyncData<AuthState>) {
    return authState.value.session?.user.id;
  }
  return null;
});

final currentUserProvider = FutureProvider<UserModel>((ref) async {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null || uid.isEmpty) throw Exception('Not authenticated');
  final user = await SupabaseService.instance.getCurrentUser();
  cacheManager.touch('profile', CacheDurations.profile);
  return user;
});
