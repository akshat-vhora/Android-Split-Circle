import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/profile_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/utils/input_sanitizer.dart';
import '../../../shared/widgets/loading_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final sanitized = InputSanitizer.sanitizeDisplayName(
                controller.text,
              );
              if (sanitized.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name cannot be empty')),
                );
                return;
              }
              Navigator.pop(ctx, sanitized);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name != currentName) {
      await ref.read(profileRepositoryProvider).updateDisplayName(uid, name);
      ref.invalidate(currentUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated!')));
      }
    }
  }

  Future<void> _editUpiId(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String? currentUpiId,
  ) async {
    final controller = TextEditingController(text: currentUpiId ?? '');
    final newUpiId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UPI ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your UPI ID to receive payments (e.g. name@bank).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                hintText: 'example@upi',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      controller.text = data!.text!.trim();
                    }
                  },
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) {
                Navigator.pop(ctx, '');
                return;
              }
              if (!val.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid UPI ID')),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newUpiId == null) return;
    try {
      if (newUpiId.isEmpty) {
        await ref.read(profileRepositoryProvider).clearUpiId(uid);
      } else {
        await ref.read(profileRepositoryProvider).updateUpiId(uid, newUpiId);
      }
      ref.invalidate(currentUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newUpiId.isEmpty ? 'UPI ID cleared' : 'UPI ID updated!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update UPI ID: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionHeader(context, 'Appearance'),
          GlassCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _themeOption(
                  context,
                  themeMode,
                  ThemeMode.system,
                  'System Default',
                  'Follow device theme',
                  Icons.settings_suggest_outlined,
                  ref,
                ),
                _menuDivider(context),
                _themeOption(
                  context,
                  themeMode,
                  ThemeMode.light,
                  'Light',
                  'Light mode',
                  Icons.light_mode_outlined,
                  ref,
                ),
                _menuDivider(context),
                _themeOption(
                  context,
                  themeMode,
                  ThemeMode.dark,
                  'Dark',
                  'Dark mode',
                  Icons.dark_mode_outlined,
                  ref,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Profile'),
          userAsync.when(
            loading: () => const ShimmerSettings(),
            error: (e, _) {
              debugPrint('Settings error: $e');
              return const SizedBox();
            },
            data: (user) => GlassCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _menuItem(
                    context,
                    Icons.edit_outlined,
                    'Display name',
                    user.displayName,
                    () => _editDisplayName(
                      context,
                      ref,
                      user.uid,
                      user.displayName,
                    ),
                  ),
                  _menuDivider(context),
                  _menuItem(
                    context,
                    Icons.payment_outlined,
                    'UPI ID',
                    user.upiId != null && user.upiId!.isNotEmpty
                        ? user.upiId!
                        : 'Not set',
                    () => _editUpiId(
                      context,
                      ref,
                      user.uid,
                      user.upiId,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (Supabase
                  .instance
                  .client
                  .auth
                  .currentSession
                  ?.user
                  .appMetadata['provider'] !=
              'google') ...[
            const SizedBox(height: 24),
            _sectionHeader(context, 'Account'),
            userAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) {
                debugPrint('Settings account error: $e');
                return const SizedBox();
              },
              data: (user) => GlassCard(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                child: _menuItem(
                  context,
                  Icons.lock_outlined,
                  'Reset password',
                  'Send reset link to ${user.email}',
                  () async {
                    showLoadingDialog(
                      context,
                      message: 'Sending reset link...',
                    );
                    try {
                      await ref
                          .read(authRepositoryProvider)
                          .resetPassword(user.email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset email sent!'),
                            backgroundColor: Color(0xFF34D399),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Reset password error: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to send reset link. Please try again.',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                    }
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _sectionHeader(context, 'Session'),
          GlassCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
              onTap: () async {
                showLoadingDialog(context, message: 'Signing out...');
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeMode current,
    ThemeMode value,
    String title,
    String subtitle,
    IconData icon,
    WidgetRef ref,
  ) {
    final selected = current == value;
    return InkWell(
      onTap: () => ref.read(themeModeProvider.notifier).setTheme(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _menuDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      endIndent: 12,
      color: Theme.of(context).dividerTheme.color,
    );
  }
}

class ShimmerSettings extends StatelessWidget {
  const ShimmerSettings({super.key});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _shimmerTile(context),
          const Divider(height: 1, indent: 60, endIndent: 12),
          _shimmerTile(context),
        ],
      ),
    );
  }

  Widget _shimmerTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
