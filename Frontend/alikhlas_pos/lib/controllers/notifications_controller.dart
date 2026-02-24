import 'dart:async';
import 'package:get/get.dart';
import '../services/api_service.dart';

/// Notification model for a single alert item
class AppNotification {
  final String type; // 'installment' | 'lowstock'
  final String title;
  final String subtitle;
  final bool isWarning;

  const AppNotification({
    required this.type,
    required this.title,
    required this.subtitle,
    this.isWarning = false,
  });
}

/// Polls GET /api/notifications every 5 minutes and exposes the badge count.
class NotificationsController extends GetxController {
  final RxInt unreadCount = 0.obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxBool isLoading = false.obs;

  Timer? _refreshTimer;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications(); // initial load
    // Refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => fetchNotifications());
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }

  Future<void> fetchNotifications() async {
    isLoading.value = true;
    try {
      final data = await ApiService.get('notifications');
      _parseNotifications(data as Map<String, dynamic>);
    } catch (_) {
      // Fail silently — notifications are not mission-critical
    } finally {
      isLoading.value = false;
    }
  }

  void _parseNotifications(Map<String, dynamic> data) {
    final list = <AppNotification>[];

    // Overdue installments
    final installments = data['installments'] as Map<String, dynamic>?;
    if (installments != null) {
      final items = (installments['items'] as List?) ?? [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        list.add(AppNotification(
          type: 'installment',
          title: 'قسط متأخر — ${m['customerName']}',
          subtitle: '${m['amount']} ج.م • متأخر ${m['daysOverdue']} يوم',
          isWarning: (m['daysOverdue'] as int? ?? 0) > 7,
        ));
      }

      // Due soon (not overdue yet)
      final dueSoon = installments['dueSoonCount'] as int? ?? 0;
      if (dueSoon > 0) {
        list.add(AppNotification(
          type: 'installment',
          title: '$dueSoon أقساط تستحق قريباً',
          subtitle: 'خلال الـ 3 أيام القادمة',
        ));
      }
    }

    // Low stock products
    final lowStock = data['lowStock'] as Map<String, dynamic>?;
    if (lowStock != null) {
      final items = (lowStock['items'] as List?) ?? [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        final qty = m['stockQuantity'] as int? ?? 0;
        list.add(AppNotification(
          type: 'lowstock',
          title: 'مخزون منخفض — ${m['name']}',
          subtitle: qty <= 0 ? 'نفد من المخزن!' : 'متبقي: $qty قطعة',
          isWarning: qty <= 0,
        ));
      }
    }

    notifications.value = list;
    unreadCount.value = data['totalUnread'] as int? ?? list.length;
  }

  void markAllRead() => unreadCount.value = 0;
}
