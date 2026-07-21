import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Sliding-window rate limiter for client-side throttling.
/// Prevents brute-force / DoS on auth endpoints by limiting
/// requests per operation within a time window.
///
/// This is a client-side defense layer. Server-side rate limiting
/// (Supabase / Edge Functions) provides the primary protection.
class RateLimiter {
  final int maxAttempts;
  final Duration windowDuration;
  final String operation;

  final _timestamps = Queue<DateTime>();

  RateLimiter({
    required this.operation,
    this.maxAttempts = 5,
    this.windowDuration = const Duration(seconds: 30),
  });

  /// Returns true if the operation is allowed, false if rate-limited.
  bool allow() {
    final now = DateTime.now();
    final cutoff = now.subtract(windowDuration);

    // Remove timestamps outside the window
    while (_timestamps.isNotEmpty && _timestamps.first.isBefore(cutoff)) {
      _timestamps.removeFirst();
    }

    if (_timestamps.length >= maxAttempts) {
      final retryAfter = _timestamps.first.difference(cutoff);
      debugPrint(
        '⏳ Rate limited [$operation]: retry after ${retryAfter.inSeconds}s',
      );
      return false;
    }

    _timestamps.add(now);
    return true;
  }

  /// Seconds until the next attempt is allowed.
  int get retryAfterSeconds {
    if (_timestamps.length < maxAttempts) return 0;
    final retryAt = _timestamps.first.add(windowDuration);
    final remaining = retryAt.difference(DateTime.now());
    return remaining.inSeconds.clamp(0, windowDuration.inSeconds);
  }

  void reset() => _timestamps.clear();
}

/// Pre-configured rate limiters for auth operations
class AuthRateLimiters {
  static final login = RateLimiter(
    operation: 'login',
    maxAttempts: 5,
    windowDuration: Duration(seconds: 30),
  );
  static final signUp = RateLimiter(
    operation: 'signup',
    maxAttempts: 3,
    windowDuration: Duration(minutes: 1),
  );
  static final passwordReset = RateLimiter(
    operation: 'password_reset',
    maxAttempts: 2,
    windowDuration: Duration(minutes: 5),
  );
  static final googleSignIn = RateLimiter(
    operation: 'google_signin',
    maxAttempts: 5,
    windowDuration: Duration(seconds: 30),
  );
}
