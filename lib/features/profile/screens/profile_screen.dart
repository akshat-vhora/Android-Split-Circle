import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../friends/providers/friends_providers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/qr_widget.dart';
import '../../../services/cache_manager.dart';
import '../../../shared/utils/currency_formatter.dart';

bool _isGoogleSignIn() {
  final u = Supabase.instance.client.auth.currentUser;
  if (u == null) return false;
  return u.appMetadata['provider'] == 'google';
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showQrCode(BuildContext context, String uniqueId) {
    final qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your QR Code',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: qrKey,
                child: QrWidget(data: uniqueId, size: 220),
              ),
              const SizedBox(height: 12),
              Text(
                'Ask your friend to scan this QR in the app',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share QR'),
                onPressed: () async {
                  try {
                    final boundary =
                        qrKey.currentContext?.findRenderObject()
                            as RenderRepaintBoundary?;
                    if (boundary == null) return;
                    final image = await boundary.toImage(pixelRatio: 3);
                    final byteData = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    if (byteData == null) return;
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/splitcircle_qr.png');
                    await file.writeAsBytes(byteData.buffer.asUint8List());
                    if (context.mounted) {
                      Navigator.pop(context);
                      await Share.shareXFiles([
                        XFile(file.path),
                      ], text: 'Add me on Split Circle! My ID: $uniqueId');
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final balanceAsync = ref.watch(balanceSummaryProvider);
    final friendsAsync = ref.watch(friendsListProvider);
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xFF16162A).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Profile error: $e');
          return Center(
            child: Text(
              'Could not load profile.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
        data: (user) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Avatar with gradient border ────────────────────
            Center(
              child: CustomPaint(
                painter: _GradientBorderPainter(
                  strokeWidth: 3,
                  colors: const [
                    Color(0xFF32E3CF),
                    Color(0xFF0BADBC),
                    Color(0xFF40A0F6),
                    Color(0xFF126CDE),
                  ],
                ),
                child: AvatarWidget(
                  imageUrl: null,
                  name: user.displayName,
                  radius: 52,
                  fontSize: 60,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── User Info ──────────────────────────────────────
            Center(
              child: Text(
                user.displayName,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                user.email,
                style: TextStyle(fontSize: 14, color: textMuted),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Member since ${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ),

            const SizedBox(height: 4),
            if (_isGoogleSignIn())
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Signed in with Google',
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),

            // ── Edit Profile Button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats Row ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    'Owed to you',
                    formatAmount(
                      balanceAsync.asData?.value['totalOwed'] ?? 0,
                    ),
                    Icons.arrow_circle_up,
                    const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard(
                    context,
                    'You owe',
                    formatAmount(balanceAsync.asData?.value['totalOwe'] ?? 0),
                    Icons.arrow_circle_down,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Info Badges Row ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoBadge(
                  context,
                  '${friendsAsync.asData?.value.length ?? 0} friends',
                  const Color(0xFF34D399),
                ),
                const SizedBox(width: 8),
                _infoBadge(
                  context,
                  'ID: ${user.uniqueId}',
                  const Color(0xFFFFD166),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Menu Sections ──────────────────────────────────
            _sectionHeader(context, 'Social'),
            _buildMenuItem(
              context: context,
              icon: Icons.share_rounded,
              title: 'Share App',
              subtitle: 'Invite friends to Split Circle',
              color: const Color(0xFF126CDE),
              onTap: () {
                final text =
                    'Join me on Split Circle! Download the app and add me using my ID: ${user.uniqueId}';
                Clipboard.setData(ClipboardData(text: text));
                HapticFeedback.lightImpact();
                Share.share(text, subject: 'Join me on Split Circle');
              },
            ),
            const SizedBox(height: 6),
            _buildMenuItem(
              context: context,
              icon: Icons.qr_code_rounded,
              title: 'My QR Code',
              subtitle: 'Let others scan to add you',
              color: const Color(0xFF42A5F5),
              onTap: () => _showQrCode(context, user.uniqueId),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.person_add_rounded,
              title: 'Invite Friends',
              subtitle: 'Share the app invite link',
              color: const Color(0xFF06D6A0),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text: 'Join me on Split Circle! My ID: ${user.uniqueId}',
                  ),
                );
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite text copied!'),
                    backgroundColor: Color(0xFF06D6A0),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            _sectionHeader(context, 'Preferences'),
            _buildMenuItem(
              context: context,
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: 'Light, Dark, or System default',
              color: const Color(0xFFF59E0B),
              onTap: () => context.push('/settings'),
            ),

            const SizedBox(height: 20),
            _sectionHeader(context, 'Support'),
            _buildMenuItem(
              context: context,
              icon: Icons.star_outline_rounded,
              title: 'Rate the App',
              subtitle: 'Love Split Circle? Leave a review',
              color: const Color(0xFFFFD166),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rate us on the app store!')),
                );
              },
            ),
            const SizedBox(height: 6),
            _buildMenuItem(
              context: context,
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'FAQs, feedback, and contact us',
              color: const Color(0xFF78909C),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support page coming soon!')),
                );
              },
            ),
            const SizedBox(height: 6),
            _buildMenuItem(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              color: const Color(0xFF0BADBC),
              onTap: () => context.push('/privacy'),
            ),
            const SizedBox(height: 6),
            _buildMenuItem(
              context: context,
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Rules and guidelines',
              color: const Color(0xFF42A5F5),
              onTap: () => context.push('/terms'),
            ),

            const SizedBox(height: 24),

            // ── Sign Out ───────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                          onPressed: () async {
                                    Navigator.pop(ctx);
                                    await ref.read(authRepositoryProvider).signOut();
                                    ref.invalidate(currentUserProvider);
                                    ref.invalidate(balanceSummaryProvider);
                                    ref.invalidate(friendsListProvider);
                                    ref.invalidate(friendBalancesProvider);
                                    cacheManager.clearAll();
                                    if (context.mounted) context.go('/login');
                                  },
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(color: Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C2E).withValues(alpha: 0.75)
            : const Color(0xFFFFFBFA).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(BuildContext context, String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.18),
            color.withValues(alpha: isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xFF16162A).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                if (trailing != null)
                  trailing
                else
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double strokeWidth;
  final List<Color> colors;

  _GradientBorderPainter({required this.strokeWidth, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(rect.center, size.width / 2 - strokeWidth / 2, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter old) =>
      old.strokeWidth != strokeWidth || old.colors != colors;
}
