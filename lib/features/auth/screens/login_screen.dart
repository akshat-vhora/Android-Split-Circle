import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_providers.dart';
import '../../../services/rate_limiter.dart';
import '../../../shared/utils/input_sanitizer.dart';
import '../../../shared/widgets/loading_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!AuthRateLimiters.login.allow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again in ${AuthRateLimiters.login.retryAfterSeconds}s.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final email = InputSanitizer.sanitizeEmail(_emailController.text);
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: _passwordController.text);
      if (mounted) {
        context.go('/');
      }
    } on AuthException catch (e) {
      AuthRateLimiters.login.reset();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your email address first')),
        );
      }
      return;
    }
    final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w\-]+$');
    if (!emailRegex.hasMatch(email)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid email address')),
        );
      }
      return;
    }
    if (!AuthRateLimiters.passwordReset.allow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again in ${AuthRateLimiters.passwordReset.retryAfterSeconds}s.',
            ),
          ),
        );
      }
      return;
    }

    // Check if email is registered and what provider it uses
    final provider = await ref
        .read(authRepositoryProvider)
        .checkEmailProvider(email);
    if (provider == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found with this email address.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
    if (provider == 'google') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This email uses Google Sign-In. Please sign in with Google instead.',
            ),
            backgroundColor: Color(0xFFFFD166),
          ),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    showLoadingDialog(context, message: 'Sending reset link...');
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            backgroundColor: Color(0xFF34D399),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _googleSignIn() async {
    if (!AuthRateLimiters.googleSignIn.allow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again in ${AuthRateLimiters.googleSignIn.retryAfterSeconds}s.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 80),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: const [Color(0xFF2A2A3E), Color(0xFF1A1A2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/login.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                // const SizedBox(height: 6),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: const [
                      Color(0xFF126CDE),
                      Color(0xFF40A0F6),
                      Color(0xFF0BADBC),
                      Color(0xFF32E3CF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Split Circle',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Split expenses with friends',
                  style: TextStyle(fontSize: 15, color: surfaceVariant),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Required';
                    }
                    final emailRegex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w\-]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: const Color(0xFF126CDE)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF126CDE),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(
                      0xFF126CDE,
                    ).withValues(alpha: 0.5),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _googleSignIn,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(
                      color: Color(0xFF126CDE),
                      width: 1.5,
                    ),
                    foregroundColor: const Color(0xFF126CDE),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF126CDE),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(color: Color(0xFF126CDE)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: surfaceVariant),
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(color: const Color(0xFF126CDE)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
