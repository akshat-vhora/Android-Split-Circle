import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/notifications_providers.dart';
import '../../../shared/models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    await ref.read(unreadCountProvider.notifier).load();
  }

  Future<void> _markAllRead() async {
    final repo = ref.read(notificationsRepositoryProvider);
    await repo.markAllAsRead();
    ref.invalidate(notificationsProvider);
    ref.read(unreadCountProvider.notifier).reset();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    final repo = ref.read(notificationsRepositoryProvider);
    await repo.clearAll();
    ref.invalidate(notificationsProvider);
    ref.read(unreadCountProvider.notifier).reset();
    setState(() => _isDeleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
            onPressed: _markAllRead,
          ),
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear all',
            onPressed: _isDeleting ? null : _clearAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorState(context, isDark),
          data: (notifications) {
            if (notifications.isEmpty) return _buildEmptyState(context, isDark);
            final groups = _groupByDate(notifications);
            final sectionKeys = groups.keys.toList();
            return _buildNotificationList(groups, sectionKeys, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Couldn\'t load notifications',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Tap to retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF1C1C2E)
                            : const Color(0xFFF1F5F9))
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 40,
                    color: isDark
                        ? const Color(0xFF9E9EB8)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'All caught up',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New notifications will show up here',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF9E9EB8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, List<NotificationModel>> _groupByDate(
    List<NotificationModel> notifications,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<NotificationModel>>{};
    for (final n in notifications) {
      final date = DateTime(
        n.createdAt.year,
        n.createdAt.month,
        n.createdAt.day,
      );
      String key;
      if (date == today) {
        key = 'Today';
      } else if (date == yesterday) {
        key = 'Yesterday';
      } else if (date.isAfter(weekAgo)) {
        key = 'This Week';
      } else {
        key = 'Earlier';
      }
      groups.putIfAbsent(key, () => []).add(n);
    }

    final ordered = <String, List<NotificationModel>>{};
    for (final key in ['Today', 'Yesterday', 'This Week', 'Earlier']) {
      if (groups.containsKey(key)) ordered[key] = groups[key]!;
    }
    return ordered;
  }

  Widget _buildNotificationList(
    Map<String, List<NotificationModel>> groups,
    List<String> sectionKeys,
    bool isDark,
  ) {
    final items = <_ListItem>[];
    for (final section in sectionKeys) {
      items.add(_ListItem.header(section));
      for (final notification in groups[section]!) {
        items.add(_ListItem.notification(notification));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _buildSectionHeader(item.headerText!, isDark);
        }

        final notification = item.notification!;
        final isFirstInSection = index > 0 && items[index - 1].isHeader;
        return _NotificationTile(
          key: ValueKey(notification.id),
          notification: notification,
          isDark: isDark,
          isFirst: isFirstInSection,
          onTap: () => _onTap(notification),
          onDelete: () => _onDelete(notification),
          onMarkRead: () {
            ref.read(unreadCountProvider.notifier).decrement();
            ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
            ref.invalidate(notificationsProvider);
          },
        );
      },
    );
  }

  void _onTap(NotificationModel notification) {
    if (!notification.isRead) {
      ref.read(unreadCountProvider.notifier).decrement();
      ref.read(notificationsRepositoryProvider).markAsRead(notification.id);
      ref.invalidate(notificationsProvider);
    }
    _handleNavigation(notification);
  }

  Future<void> _onDelete(NotificationModel notification) async {
    if (!notification.isRead) {
      ref.read(unreadCountProvider.notifier).decrement();
    }
    ref.read(notificationsRepositoryProvider).deleteNotification(notification.id);
    ref.invalidate(notificationsProvider);
  }

  Widget _buildSectionHeader(String label, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, label == 'Today' ? 8 : 20, 20, 4),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF9E9EB8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  void _handleNavigation(NotificationModel notification) {
    final expenseId = notification.data['expense_id'] as String?;
    final friendUid = notification.data['friend_uid'] as String?;
    if (expenseId != null) {
      context.push('/expenses/$expenseId');
    } else if (friendUid != null) {
      context.push('/friends/$friendUid');
    }
  }
}

class _ListItem {
  final bool isHeader;
  final String? headerText;
  final NotificationModel? notification;

  _ListItem._({this.isHeader = false, this.headerText, this.notification});

  factory _ListItem.header(String text) =>
      _ListItem._(isHeader: true, headerText: text);

  factory _ListItem.notification(NotificationModel n) =>
      _ListItem._(notification: n);
}

class _NotificationTile extends StatefulWidget {
  final NotificationModel notification;
  final bool isDark;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    super.key,
    required this.notification,
    required this.isDark,
    required this.isFirst,
    required this.onTap,
    required this.onDelete,
    required this.onMarkRead,
  });

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Dismissible(
        key: ValueKey('dismiss_${widget.notification.id}'),
        direction: DismissDirection.horizontal,
        background: _readBackground(),
        secondaryBackground: _deleteBackground(),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            final delete = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete notification?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                ],
              ),
            );
            if (delete == true) {
              widget.onDelete();
              return true;
            }
            return false;
          } else {
            if (!widget.notification.isRead) {
              widget.onMarkRead();
            }
            return false;
          }
        },
        child: _NotificationContent(
          notification: widget.notification,
          isDark: widget.isDark,
          isFirst: widget.isFirst,
          onTap: widget.onTap,
        ),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
    );
  }

  Widget _readBackground() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.done_all_rounded, color: Color(0xFF60A5FA)),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  final NotificationModel notification;
  final bool isDark;
  final bool isFirst;
  final VoidCallback onTap;

  const _NotificationContent({
    required this.notification,
    required this.isDark,
    required this.isFirst,
    required this.onTap,
  });

  Color _iconColor() {
    switch (notification.type) {
      case 'friend_added':
        return const Color(0xFF34D399);
      case 'expense_added':
        return const Color(0xFF60A5FA);
      case 'settlement_requested':
        return const Color(0xFFFFD166);
      case 'settlement_confirmed':
        return const Color(0xFF34D399);
      case 'settlement_rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9E9EB8);
    }
  }

  IconData _icon() {
    switch (notification.type) {
      case 'friend_added':
        return Icons.person_add_rounded;
      case 'expense_added':
        return Icons.receipt_long_rounded;
      case 'settlement_requested':
        return Icons.handshake_rounded;
      case 'settlement_confirmed':
        return Icons.check_circle_rounded;
      case 'settlement_rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadColor = _iconColor();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: isFirst ? 4 : 10,
          bottom: 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _iconColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_icon(), color: _iconColor(), size: 22),
                ),
                if (!notification.isRead)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: unreadColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0B0B14)
                              : const Color(0xFFF8FAFC),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 15,
                            height: 1.3,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF9E9EB8)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  if (notification.body != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? const Color(0xFF9E9EB8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
