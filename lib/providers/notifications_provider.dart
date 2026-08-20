import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_client.dart';
import 'app_refresh_provider.dart';

class NotificationItem {
  final int id;
  final int userId;
  final int announcementId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic>? announcement;
  final String? redirectUrl;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.announcementId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.announcement,
    this.redirectUrl,
  });

  factory NotificationItem.fromMap(
    Map<String, dynamic> m,
  ) {
    return NotificationItem(
      id: (m['id'] as num).toInt(),
      userId: (m['user_id'] as num).toInt(),
      announcementId: (m['announcement_id'] as num).toInt(),
      isRead: m['is_read'] == true,
      readAt: m['read_at'] != null
          ? DateTime.tryParse(
              m['read_at'].toString(),
            )
          : null,
      createdAt:
          DateTime.tryParse(
            m['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      announcement: m['announcement'] is Map
          ? Map<String, dynamic>.from(
              m['announcement'],
            )
          : null,
      redirectUrl: m['redirect_url']?.toString(),
    );
  }

  // ============================================================
  // DISPLAY PROPERTIES
  // ============================================================

  String get title {
    final value =
        announcement?['title']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'Announcement';
    }

    return value;
  }

  String get message {
    return announcement?['content']?.toString() ?? '';
  }

  String get dateText {
    final date = createdAt.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  String get priority {
    final value =
        announcement?['priority']
            ?.toString()
            .trim()
            .toLowerCase();

    if (value == null || value.isEmpty) {
      return 'medium';
    }

    return value;
  }

  IconData get icon {
    switch (priority) {
      case 'high':
        return Icons.warning_amber_rounded;

      case 'low':
        return Icons.check_circle_outline_rounded;

      case 'medium':
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'high':
        return const Color(0xFFFFECE2);

      case 'low':
        return const Color(0xFFE2F9F0);

      case 'medium':
      default:
        return const Color(0xFFE1EFFF);
    }
  }

  Color get priorityTextColor {
    switch (priority) {
      case 'high':
        return const Color(0xFFE66A00);

      case 'low':
        return const Color(0xFF16805B);

      case 'medium':
      default:
        return const Color(0xFF2673EC);
    }
  }

  bool get supportsReadActions => true;
}

// ============================================================
// NOTIFICATIONS CONTROLLER
// ============================================================

class NotificationsNotifier
    extends StateNotifier<
        AsyncValue<List<NotificationItem>>> {
  final Ref ref;

  RealtimeChannel? _notificationChannel;

  bool _disposed = false;
  bool _loading = false;
  bool _subscribed = false;

  NotificationsNotifier(this.ref)
      : super(
          const AsyncValue.loading(),
        ) {
    _initialize();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    if (_disposed) {
      return;
    }

    // IMPORTANT:
    // Subscribe FIRST so we don't miss realtime events
    // while the initial notification list is loading.
    await _subscribeToRealtime();

    if (_disposed) {
      return;
    }

    await _load();
  }

  // ============================================================
  // LOAD NOTIFICATIONS
  // ============================================================

  Future<void> _load() async {
    if (_disposed || _loading) {
      return;
    }

    _loading = true;

    try {
      debugPrint(
        '📥 Loading notifications...',
      );

      final rows =
          await ApiClient.instance.getNotifications();

      if (_disposed) {
        return;
      }

      final items = rows
          .map(
            (row) => NotificationItem.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();

      debugPrint(
        '✅ Notifications loaded: ${items.length}',
      );

      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Failed to load notifications: $error',
      );

      if (!_disposed) {
        state = AsyncValue.error(
          error,
          stackTrace,
        );
      }
    } finally {
      _loading = false;
    }
  }

  // ============================================================
  // SUPABASE REALTIME
  // ============================================================

Future<void> _subscribeToRealtime() async {
  if (_disposed) {
    return;
  }

  if (_subscribed) {
    debugPrint('⚠️ Realtime already subscribed.');
    return;
  }

  try {
    final supabase = Supabase.instance.client;

    debugPrint('📡 Starting Notification Realtime...');

    _notificationChannel = supabase
        .channel('employee-notifications-realtime')

        // ============================================================
        // LISTEN TO ANNOUNCEMENT NOTIFICATIONS
        // ============================================================
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcement_notifications',
          callback: (payload) {
            if (_disposed) {
              return;
            }

            debugPrint('========================================');
            debugPrint('🔔 NOTIFICATION EVENT RECEIVED');
            debugPrint('📌 Event Type: ${payload.eventType}');
            debugPrint('🆕 New Record: ${payload.newRecord}');
            debugPrint('🗑️ Old Record: ${payload.oldRecord}');
            debugPrint('========================================');

            unawaited(_load());
          },
        )

        // ============================================================
        // ALSO LISTEN TO ANNOUNCEMENTS
        // ============================================================
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            if (_disposed) {
              return;
            }

            debugPrint('========================================');
            debugPrint('📢 ANNOUNCEMENT EVENT RECEIVED');
            debugPrint('📌 Event Type: ${payload.eventType}');
            debugPrint('🆕 New Announcement: ${payload.newRecord}');
            debugPrint('🗑️ Old Announcement: ${payload.oldRecord}');
            debugPrint('========================================');

            unawaited(_load());
          },
        )

        .subscribe(
      (status, error) {
        debugPrint(
          '📡 Notification Realtime status: $status',
        );

        if (error != null) {
          debugPrint(
            '❌ Notification Realtime error: $error',
          );
        }

        if (status ==
            RealtimeSubscribeStatus.subscribed) {
          _subscribed = true;

          debugPrint(
            '✅ Notification Realtime connected',
          );

          debugPrint(
            '👂 Listening to:',
          );

          debugPrint(
            '   • public.announcement_notifications',
          );

          debugPrint(
            '   • public.announcements',
          );
        }

        if (status ==
            RealtimeSubscribeStatus.channelError) {
          _subscribed = false;

          debugPrint(
            '❌ Notification Realtime channel error',
          );
        }

        if (status ==
            RealtimeSubscribeStatus.closed) {
          _subscribed = false;

          debugPrint(
            '⚠️ Notification Realtime channel closed',
          );
        }

        if (status ==
            RealtimeSubscribeStatus.timedOut) {
          _subscribed = false;

          debugPrint(
            '⏱️ Notification Realtime timed out',
          );
        }
      },
    );
  } catch (error, stackTrace) {
    debugPrint(
      '❌ Failed to subscribe to Notification Realtime:',
    );

    debugPrint('$error');
    debugPrint('$stackTrace');
  }
}
  // ============================================================
  // MANUAL REFRESH
  // ============================================================

  Future<void> refresh() {
    return _load();
  }

  // ============================================================
  // MARK ONE AS READ
  // ============================================================

  Future<void> markNotificationRead(
    String notificationId,
  ) async {
    try {
      await ApiClient.instance
          .markNotificationRead(
        notificationId,
      );

      await _load();
      ref.read(appRefreshProvider.notifier).trigger();
    } catch (error) {
      debugPrint(
        '❌ Failed to mark notification as read: '
        '$error',
      );

      rethrow;
    }
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<void> markAllRead() async {
    try {
      await ApiClient.instance
          .markAllNotificationsRead();

      await _load();
      ref.read(appRefreshProvider.notifier).trigger();
    } catch (error) {
      debugPrint(
        '❌ Failed to mark all notifications as read: '
        '$error',
      );

      rethrow;
    }
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  Future<void> clearAll() async {
    try {
      await ApiClient.instance
          .clearAllNotifications();

      await _load();
      ref.read(appRefreshProvider.notifier).trigger();
    } catch (error) {
      debugPrint(
        '❌ Failed to clear notifications: '
        '$error',
      );

      rethrow;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    debugPrint(
      '🧹 Disposing Notification Realtime...',
    );

    _disposed = true;
    _subscribed = false;

    final channel = _notificationChannel;

    if (channel != null) {
      Supabase.instance.client
          .removeChannel(channel);

      _notificationChannel = null;
    }

    super.dispose();
  }
}

// ============================================================
// RIVERPOD PROVIDER
// ============================================================

final notificationsControllerProvider =
    StateNotifierProvider<
        NotificationsNotifier,
        AsyncValue<List<NotificationItem>>>(
  (ref) {
    return NotificationsNotifier(ref);
  },
);