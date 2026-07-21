import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/friends_providers.dart';
import '../../../shared/models/friend_balance_model.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/qr_widget.dart';
import '../../../shared/widgets/shimmer_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/currency_formatter.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});
  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final balancesAsync = ref.watch(friendBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final surface = isDark
        ? const Color(0xFF16162A).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_friend',
        onPressed: () => context.push('/friends/add'),
        child: const Icon(Icons.group_add_rounded),
      ),
      body: friendsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) {
          debugPrint('Friends list error: $e');
          return Center(
            child: Text(
              'Could not load friends.',
              style: TextStyle(color: textMuted),
            ),
          );
        },
        data: (friends) {
          final filtered = _searchQuery.isEmpty
              ? friends
              : friends
                    .where(
                      (f) => f.displayName.toLowerCase().contains(_searchQuery),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(friendsRefreshProvider.notifier).trigger();
              ref.invalidate(friendBalancesProvider);
            },
            child: friends.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyState(
                        icon: Icons.people_outlined,
                        title: 'No friends yet',
                        subtitle:
                            'Add friends using their unique ID or QR code',
                      ),
                    ],
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ── Search Bar ──────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search friends',
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                          ),
                        ),
                      ),
                      // ── Invite Banner ──────────────────────
                      if (_searchQuery.isEmpty && friends.isNotEmpty)
                        SliverToBoxAdapter(child: _inviteBanner(context)),
                      // ── Friend List ────────────────────────
                      if (_searchQuery.isNotEmpty && filtered.isEmpty)
                        const SliverFillRemaining(
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: 'No friends found',
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final friend = filtered[index];
                            final balanceMap =
                                balancesAsync.asData?.value ??
                                <String, FriendBalanceModel?>{};
                            final balance = balanceMap[friend.uid];
                            final amount = balance?.amount ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () =>
                                        context.push('/friends/${friend.uid}'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          AvatarWidget(
                                            imageUrl: null,
                                            name: friend.displayName,
                                            radius: 22,
                                            fontSize: 16,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  friend.displayName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      amount == 0
                                                          ? 'Settled up'
                                                          : amount > 0
                                                          ? 'They owe ${formatAmount(amount)}'
                                                          : 'You owe ${formatAmount(amount.abs())}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: amount > 0
                                                            ? const Color(
                                                                0xFF34D399,
                                                              )
                                                            : amount < 0
                                                            ? const Color(
                                                                0xFFEF4444,
                                                              )
                                                            : textMuted,
                                                      ),
                                                    ),
                                                    // const SizedBox(width: 8),
                                                    // Text(friend.uniqueId, style: TextStyle(fontSize: 11, color: textMuted)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          _qrButton(context, friend.uniqueId),
                                          const SizedBox(width: 6),
                                          // _balancePill(amount),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }, childCount: filtered.length),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _showFriendQr(BuildContext context, String uniqueId) {
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
                "Friend's QR Code",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: QrWidget(data: uniqueId, size: 200),
              ),
              const SizedBox(height: 12),
              Text(
                'ID: $uniqueId',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy ID'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uniqueId));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('ID copied!')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrButton(BuildContext context, String uniqueId) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showFriendQr(context, uniqueId),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            Icons.qr_code_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _inviteBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
              Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: isDark ? 0.1 : 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/friends/add'),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a friend',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share expenses by inviting friends',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
