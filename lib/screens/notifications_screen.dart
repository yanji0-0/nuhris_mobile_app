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
                              key: ValueKey(item.id),
                              item: item,
                              onOpened: () async {
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

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.onOpened,
  });

  final NotificationItem item;
  final VoidCallback onOpened;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _expanded = false;

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

  void _handleTap() {
    final wasExpanded = _expanded;
    setState(() {
      _expanded = !_expanded;
    });

    // Preserve existing unread → read behavior on tap/open.
    if (!wasExpanded) {
      widget.onOpened();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isRead = item.isRead;
    final titleColor =
        isRead ? const Color(0xFF7A8699) : const Color(0xFF141B2E);
    final messageColor =
        isRead ? const Color(0xFF9AA6B8) : const Color(0xFF2A324A);
    final dateColor =
        isRead ? const Color(0xFFA3AEBF) : const Color(0xFF4C5A73);
    final iconBg = isRead
        ? const Color(0xFFE8ECF2)
        : _getIconBackground(item.priority);
    final iconColor =
        isRead ? const Color(0xFF9AA6B8) : _getIconColor(item.priority);
    final chevronColor =
        isRead ? const Color(0xFFB0B9C8) : const Color(0xFF8A95A8);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _handleTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: isRead ? const Color(0xFFF3F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? const Color(0xFFDCE3EE) : const Color(0xFFE6ECF6),
            ),
            boxShadow: isRead
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x0B0B1E43),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: iconColor,
                  size: 18,
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
                            maxLines: _expanded ? null : 1,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 16,
                              height: 1.3,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
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
                        Opacity(
                          opacity: isRead ? 0.55 : 1,
                          child: Container(
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
                        ),
                      ],
                    ),
                    SizedBox(height: _expanded ? 8 : 4),
                    Text(
                      item.message,
                      maxLines: _expanded ? null : 1,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: messageColor,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: _expanded ? 10 : 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: isRead
                              ? const Color(0xFFB0B9C8)
                              : const Color(0xFF7B879C),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.dateText,
                            style: TextStyle(
                              color: dateColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: chevronColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}