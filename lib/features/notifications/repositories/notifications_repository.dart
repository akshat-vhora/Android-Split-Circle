import '../../../services/supabase_service.dart';
import '../../../shared/models/notification_model.dart';

class NotificationsRepository {
  final SupabaseService _supabase = SupabaseService.instance;

  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _supabase.client.rpc(
      'get_user_notifications',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    final list = (res as List)
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return list;
  }

  Future<int> getUnreadCount() async {
    final res = await _supabase.client.rpc('get_unread_notification_count');
    return res as int;
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase.client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<void> markAllAsRead() async {
    await _supabase.client.rpc('mark_all_notifications_read');
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase.client.rpc(
      'delete_notification',
      params: {'p_notification_id': notificationId},
    );
  }

  Future<void> clearAll() async {
    await _supabase.client.rpc('clear_all_notifications');
  }
}
