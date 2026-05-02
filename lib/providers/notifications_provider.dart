import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client_provider.dart';

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
      NotificationsController.new,
    );

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() async {
    return _loadNotifications();
  }

  Future<void> refreshNotifications() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadNotifications);
  }

  Future<void> markAllRead() async {
    final api = ref.read(apiClientProvider);
    await api.markAllNotificationsRead();
    await refreshNotifications();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final api = ref.read(apiClientProvider);
    await api.markNotificationRead(notificationId);
    await refreshNotifications();
  }

  Future<void> clearAll() async {
    final api = ref.read(apiClientProvider);
    await api.clearAllNotifications();
    await refreshNotifications();
  }

  Future<List<NotificationItem>> _loadNotifications() async {
    final api = ref.read(apiClientProvider);
    final rows = await api.getNotifications();

    return rows.map((row) {
      final announcement =
          (row['announcement'] as Map?)?.cast<String, dynamic>() ?? {};
      final priority = (announcement['priority'] ?? 'low').toString();
      final category = (announcement['target_office'] ?? 'General').toString();

      return NotificationItem(
        id: (row['id'] ?? '').toString(),
        isRead: (row['is_read'] ?? false) == true,
        category: category,
        title: (announcement['title'] ?? 'Notification').toString(),
        message: (announcement['content'] ?? 'No details provided.').toString(),
        dateText: (announcement['published_at'] ?? row['created_at'] ?? '')
            .toString(),
        priority: priority,
        priorityColor: _priorityColor(priority),
        priorityTextColor: _priorityTextColor(priority),
        icon: Icons.campaign_outlined,
        iconColor: const Color(0xFF0E5AA7),
      );
    }).toList();
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFF4CD67);
      case 'medium':
        return const Color(0xFF66B6FF);
      default:
        return const Color(0xFFD1FAE5);
    }
  }

  Color _priorityTextColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFB45309);
      case 'medium':
        return const Color(0xFF0B4C8C);
      default:
        return const Color(0xFF065F46);
    }
  }
}

class NotificationItem {
  final String id;
  final bool isRead;
  final String category;
  final String title;
  final String message;
  final String dateText;
  final String priority;
  final Color priorityColor;
  final Color priorityTextColor;
  final IconData icon;
  final Color iconColor;

  const NotificationItem({
    required this.id,
    required this.isRead,
    required this.category,
    required this.title,
    required this.message,
    required this.dateText,
    required this.priority,
    required this.priorityColor,
    required this.priorityTextColor,
    required this.icon,
    required this.iconColor,
  });
}
