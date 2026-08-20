import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/nuhris_app_bar.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationsControllerProvider);

    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.notifications,
        onSelect: (item) {
          Navigator.pop(context);
          onNavigate(item);
        },
      ),
      appBar: NuhrisAppBar(
        title: 'Notifications',
        currentItem: AppNavItem.notifications,
        onNavigate: onNavigate,
        onSignOut: onSignOut,
        showNotifications: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6F8FC),
              Color(0xFFF1F4FA),
              Color(0xFFECEFF6),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF2C5FC7),
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Stay updated with credential reminders, HR announcements, and compliance alerts.',
                          style: TextStyle(
                            color: Color(0xFF4B556A),
                            fontSize: 16,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await controller.markAllRead();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlue,
                        side: const BorderSide(color: Color(0xFFCCD6E6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Read All'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        await controller.clearAll();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFCCD6E6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6ECF6)),
                  ),
                  child: notificationState.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 38,
                      ),
                      child: Text(
                        'Failed to load notifications:\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF4B556A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 30,
                          ),
                          child: Text(
                            'No notifications found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF92A0B5),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: notifications.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationCard(
                              item: item,
                              onTap: () async {
                                if (!item.isRead) {
                                  await controller.markNotificationRead(
                                    item.id.toString(),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  Color _getIconBackground(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFFECE2);
      case 'medium':
        return const Color(0xFFE1EFFF);
      default:
        return const Color(0xFFE2F9F0);
    }
  }

  Color _getIconColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF9800);
      case 'medium':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6ECF6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B0B1E43),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBackground(item.priority),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: _getIconColor(item.priority),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF141B2E),
                            fontSize: 16,
                            fontWeight:
                                item.isRead ? FontWeight.w700 : FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!item.isRead)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F0FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'UNREAD',
                            style: TextStyle(
                              color: Color(0xFF2673EC),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.priorityColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.priority.toUpperCase(),
                          style: TextStyle(
                            color: item.priorityTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2A324A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Color(0xFF7B879C),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.dateText,
                          style: const TextStyle(
                            color: Color(0xFF4C5A73),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF8A95A8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}