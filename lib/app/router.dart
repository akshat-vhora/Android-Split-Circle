import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/providers/auth_providers.dart';
import '../features/dashboard/providers/dashboard_providers.dart';
import '../features/friends/providers/friends_providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/update_password_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/expenses/screens/add_expense_screen.dart';
import '../features/expenses/screens/expense_detail_screen.dart';
import '../features/expenses/screens/expense_list_screen.dart';
import '../features/friends/screens/add_friend_screen.dart';
import '../features/friends/screens/friend_detail_screen.dart';
import '../features/friends/screens/friends_list_screen.dart';
import '../features/friends/screens/qr_scan_screen.dart';
import '../features/analytics/screens/analytics_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/legal/privacy_policy_screen.dart';
import '../features/legal/terms_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (prev, next) {
    if (next.hasValue) {
      refreshNotifier.value++;
    }
  });

  return GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: '/login',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/update-password',
        builder: (c, s) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => NoTransitionPage(
          child: const DashboardShell(child: DashboardScreen()),
        ),
      ),
      GoRoute(
        path: '/expenses',
        pageBuilder: (c, s) => NoTransitionPage(
          child: const DashboardShell(child: ExpenseListScreen()),
        ),
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (c, s) => NoTransitionPage(
          child: const DashboardShell(child: FriendsListScreen()),
        ),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (c, s) => NoTransitionPage(
          child: const DashboardShell(child: AnalyticsScreen()),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (c, s) => NoTransitionPage(
          child: const DashboardShell(child: ProfileScreen()),
        ),
      ),

      // Full-screen routes (outside shell)
      GoRoute(
        path: '/expenses/add',
        builder: (c, s) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (c, s) =>
            ExpenseDetailScreen(expenseId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/friends/add', builder: (c, s) => const AddFriendScreen()),
      GoRoute(
        path: '/friends/:uid',
        builder: (c, s) =>
            FriendDetailScreen(friendUid: s.pathParameters['uid']!),
      ),
      GoRoute(path: '/qr-scan', builder: (c, s) => const QrScanScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/privacy', builder: (c, s) => const PrivacyPolicyScreen()),
      GoRoute(path: '/terms', builder: (c, s) => const TermsScreen()),
    ],
  );
});

class DashboardShell extends ConsumerWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location == '/') currentIndex = 0;
    if (location == '/expenses') currentIndex = 1;
    if (location == '/friends') currentIndex = 2;
    if (location == '/analytics') currentIndex = 3;
    if (location == '/profile') currentIndex = 4;

    return Scaffold(
      extendBody: false,
      body: child,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            ref.invalidate(balanceSummaryProvider);
          }
          if (index == 2) {
            ref.invalidate(friendsListProvider);
            ref.invalidate(friendBalancesProvider);
          }
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/expenses');
              break;
            case 2:
              context.go('/friends');
              break;
            case 3:
              context.go('/analytics');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor:
                (isDark ? const Color(0xFF16162A) : const Color(0xFFFFFBFA))
                    .withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.18),
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
