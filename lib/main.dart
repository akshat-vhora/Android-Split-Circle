import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/expenses/providers/expenses_providers.dart';
import 'features/friends/providers/friends_providers.dart';
import 'features/notifications/providers/notifications_providers.dart';
import 'services/config_checker.dart';
import 'services/logger_service.dart';
import 'services/supabase_service.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  ConfigChecker.validate(
    supabaseUrl: SupabaseConfig.url,
    supabaseAnonKey: SupabaseConfig.anonKey,
  );

  // Initialize Firebase (required for Crashlytics & FCM)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      LoggerService.instance.error(
        'FlutterError: ${details.exception}',
        details.exception,
        details.stack,
      );
    };
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      LoggerService.instance.error('PlatformDispatcher Error', error, stack);
      return true;
    };
  } catch (e) {
    // Firebase not configured — fall back to basic logging
    FlutterError.onError = (details) {
      LoggerService.instance.error(
        'FlutterError: ${details.exception}',
        details.exception,
        details.stack,
      );
    };
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.instance.error('PlatformDispatcher Error', error, stack);
      return true;
    };
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SharedPreferences.getInstance();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: SplitCircleApp()));
}

class SplitCircleApp extends ConsumerStatefulWidget {
  const SplitCircleApp({super.key});
  @override
  ConsumerState<SplitCircleApp> createState() => _SplitCircleAppState();
}

class _SplitCircleAppState extends ConsumerState<SplitCircleApp>
    with WidgetsBindingObserver {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtimeSubscriptions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    final uid = SupabaseService.instance.currentUid;
    if (uid.isEmpty) return;

    ref.read(unreadCountProvider.notifier).load();

    Supabase.instance.client
        .channel('friendships')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          callback: (_) {
            ref.invalidate(friendsListProvider);
            ref.invalidate(friendBalancesProvider);
          },
        )
        .subscribe();

    Supabase.instance.client
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) {
            ref.read(unreadCountProvider.notifier).increment();
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(currentUserProvider);
      ref.invalidate(awaitingConfirmationProvider);
      ref.invalidate(friendsListProvider);
      ref.invalidate(friendBalancesProvider);
      ref.read(unreadCountProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(goRouterProvider);

    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Split Circle',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeMode,
        home: SplashScreen(
          onComplete: () {
            if (mounted) setState(() => _showSplash = false);
          },
        ),
      );
    }

    ref.listen(authStateProvider, (previous, next) {
      switch (next) {
        case AsyncData(:final value):
          if (value.event == AuthChangeEvent.passwordRecovery) {
            final loc = router.state.matchedLocation;
            if (loc != '/update-password') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                router.go('/update-password');
              });
            }
          }
        default:
          break;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
    });

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Split Circle',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Custom error widget — never show red screen of death
        ErrorWidget.builder = (errorDetails) => Material(
          color: const Color(0xFF0B0B14),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                  SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF1F1F6),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please restart the app and try again.',
                    style: TextStyle(color: Color(0xFF9E9EB8)),
                  ),
                ],
              ),
            ),
          ),
        );
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: child,
        );
      },
    );
  }
}
