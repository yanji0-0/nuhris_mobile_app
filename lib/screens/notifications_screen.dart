import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedTab = 'All';
  List<_NotifItem> items = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final rows = await ApiClient.instance.getNotifications();
      final mapped = rows.map((row) {
        final announcement =
            (row['announcement'] as Map?)?.cast<String, dynamic>() ?? {};
        final priority = (announcement['priority'] ?? 'low').toString();
        final category = (announcement['target_office'] ?? 'General')
            .toString();
        return _NotifItem(
          id: (row['id'] ?? '').toString(),
          isRead: (row['is_read'] ?? false) == true,
          category: category,
          title: (announcement['title'] ?? 'Notification').toString(),
          message: (announcement['content'] ?? 'No details provided.')
              .toString(),
          dateText: (announcement['published_at'] ?? row['created_at'] ?? '')
              .toString(),
          priority: priority,
          priorityColor: _priorityColor(priority),
          priorityTextColor: _priorityTextColor(priority),
          icon: Icons.campaign_outlined,
          iconColor: AppColors.primaryBlue,
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        items = mapped;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  List<String> get tabs {
    final categories = items.map((e) => e.category).toSet().toList()..sort();
    return ['All', ...categories];
  }

  List<_NotifItem> get filtered => items;

  Future<void> _markAllRead() async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.markAllNotificationsRead();
      await _loadNotifications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all read: $error')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markNotificationRead(String notificationId) async {
    try {
      await ApiClient.instance.markNotificationRead(notificationId);
      await _loadNotifications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark notification read: $error')),
      );
    }
  }

  Future<void> _clearAll() async {
    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.clearAllNotifications();
      await _loadNotifications();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear notifications: $error')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;

    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.notifications,
        onSelect: (item) {
          Navigator.pop(context);
          widget.onNavigate(item);
        },
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF0A1B66),
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F8FC), Color(0xFFF1F4FA), Color(0xFFECEFF6)],
          ),
        ),
        child: SafeArea(
          top: false,
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
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text('Failed to load notifications: $_error'),
                  ),
                )
              else ...[
                // Header actions: Read All and Clear All
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _markAllRead,
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
                      onPressed: _clearAll,
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
                if (list.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 30,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6ECF6)),
                    ),
                    child: const Text(
                      'No notifications found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF92A0B5),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  ...list.map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NotificationCard(
                        item: n,
                        onTap: n.isRead
                            ? null
                            : () => _markNotificationRead(n.id),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Tab counting removed — tabs UI replaced with Read All / Clear All actions.

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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, this.onTap});
  final _NotifItem item;
  final VoidCallback? onTap;

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
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: item.isRead ? 0.55 : 1.0,
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
                            style: const TextStyle(
                              color: Color(0xFF141B2E),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.isRead != true) ...[
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
                        ],
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
      ),
    );
  }
}

class _NotifItem {
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

  _NotifItem({
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
