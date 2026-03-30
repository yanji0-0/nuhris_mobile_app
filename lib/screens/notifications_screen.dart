import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onNavigate});

  final ValueChanged<AppNavItem> onNavigate;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedTab = 'All';

  final List<String> tabs = const [
    'All',
    'Credentials',
    'CHED',
    'HR',
    'DTR',
    'General',
  ];

  final List<_NotifItem> items = const [
    _NotifItem(
      category: 'Credentials',
      title: 'PRC License Renewal\nReminder',
      message:
          'Your PRC license is expiring in 60 days.\nPlease upload your renewed license before\nApril 15, 2026.',
      dateText: 'Feb 12, 2026 at 5:35 PM',
      priority: 'high',
      priorityColor: Color(0xFFF4CD67),
      priorityTextColor: Color(0xFFB45309),
      icon: Icons.campaign_outlined,
      iconColor: Color(0xFFE06B10),
    ),
    _NotifItem(
      category: 'DTR',
      title: 'DTR Released:\nJanuary 16-31',
      message:
          'Your Daily Time Record for the period\nJanuary 16-31, 2026 is now available for\nviewing.',
      dateText: 'Feb 12, 2026 at 5:35 PM',
      priority: 'medium',
      priorityColor: Color(0xFF66B6FF),
      priorityTextColor: Color(0xFF0B4C8C),
      icon: Icons.campaign_outlined,
      iconColor: Color(0xFF2EA44F),
    ),
    _NotifItem(
      category: 'HR',
      title: 'New Leave Policy\nUpdate',
      message:
          'Effective this semester, emergency leave\nentitlement has been increased from 3 to 5\ndays per academic year.',
      dateText: 'Feb 12, 2026 at 5:35 PM',
      priority: 'medium',
      priorityColor: Color(0xFF66B6FF),
      priorityTextColor: Color(0xFF0B4C8C),
      icon: Icons.campaign_outlined,
      iconColor: Color(0xFF6F42C1),
    ),
  ];

  List<_NotifItem> get filtered {
    if (selectedTab == 'All') return items;
    return items.where((e) => e.category == selectedTab).toList();
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
        onSignOut: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign out tapped (UI only)')),
          );
        },
      ),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: () => widget.onNavigate(AppNavItem.notifications),
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Stay updated with credential reminders, HR\nannouncements, and compliance alerts.',
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tabs container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFADADAD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((t) {
                  final isSelected = selectedTab == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => selectedTab = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE8E8E8) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                child: Text(
                  'No Notifications Found',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF454545),
                  ),
                ),
              ),
            )
          else
            ...list.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationCard(item: n),
                )),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.nuhrisYellow, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            color: Color(0x1A000000),
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(item.icon, color: item.iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.priorityColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: item.priorityTextColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      item.priority,
                      style: TextStyle(
                        color: item.priorityTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF555555),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  item.dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9C9C9C),
                    fontWeight: FontWeight.w600,
                  ),
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
  final String category;
  final String title;
  final String message;
  final String dateText;
  final String priority;
  final Color priorityColor;
  final Color priorityTextColor;
  final IconData icon;
  final Color iconColor;

  const _NotifItem({
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