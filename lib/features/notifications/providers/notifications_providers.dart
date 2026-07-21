import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/notifications_repository.dart';
import '../../../shared/models/notification_model.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> load() async {
    final repo = ref.read(notificationsRepositoryProvider);
    state = await repo.getUnreadCount();
  }

  void increment() => state = state + 1;
  void decrement() {
    if (state > 0) state--;
  }
  void reset() => state = 0;
}

final unreadCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getNotifications();
});
