import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/academic_calendar_entry.dart';
import 'api_client_contract.dart';

class ApiClient implements AppApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final SupabaseClient _client = Supabase.instance.client;
  bool _fallbackAuthenticated = false;
  Map<String, dynamic>? _user;

  bool get isAuthenticated =>
      _client.auth.currentSession != null || _fallbackAuthenticated;
  Map<String, dynamic>? get currentUser => _user;

  static const int _employeeUserType = 3;
  static const String _loginFailedMessage =
      'These credentials do not match our records.';
  static const String _profilePhotoBucket = 'credentials';
  static const String _profilePhotoPathPrefix = 'credentials/';
  static const List<String> _credentialFilesBuckets = [
    'CREDENTIALS',
    'employee_credentials',
    'employee-credentials',
    'credentials',
    'uploads',
  ];
  static const List<String> _profilePhotoBuckets = [
    'credentials',
    'profile-photos',
    'profile_photos',
    'avatars',
    'uploads',
  ];

  @override
  Future<bool> hasEmployeeAccess() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      final user = await _currentUserRow();
      final userType = _parseUserType(user?['user_type']);
      if (userType != null && userType != _employeeUserType) {
        await logout();
        return false;
      }

      final employee = await _currentEmployee();
      if (employee == null) {
        await logout();
        return false;
      }

      return true;
    } catch (_) {
      // Fall through and force logout for unresolved or invalid user records.
    }

    await logout();
    return false;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ApiException('Email and password are required.');
    }

    AuthResponse authResult;
    try {
      authResult = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } catch (error) {
      // Fallback to public users table login for projects not using Supabase Auth.
      final rows = await _client
          .from('users')
          .select('*')
          .ilike('email', normalizedEmail)
          .limit(1);

      if (rows.isEmpty) {
        throw ApiException('No account found for this email.');
      }

      final row = (rows.first as Map).cast<String, dynamic>();
      final storedPassword = (row['password'] ?? '').toString();
      final isBcrypt = storedPassword.startsWith(r'$2');
      final isValid = isBcrypt
          ? BCrypt.checkpw(password, storedPassword)
          : password == storedPassword;

      if (!isValid) {
        throw ApiException('The provided credentials are incorrect.');
      }

      final userType = _parseUserType(row['user_type']);
      if (userType != _employeeUserType) {
        throw ApiException(_loginFailedMessage);
      }

      _fallbackAuthenticated = true;
      _user = row;

      final employee = await _currentEmployee();
      if (employee == null) {
        await logout();
        throw ApiException(_loginFailedMessage);
      }

      final employeeId = employee['id'];
      if (employeeId != null) {
        await _provisionAuthUserIfMissing(
          email: normalizedEmail,
          password: password,
          employeeId: employeeId,
        );
      }
      return;
    }

    _fallbackAuthenticated = false;
    await _loadCurrentUserFromTable(normalizedEmail);

    final currentUserType = _parseUserType(_user?['user_type']);
    if (currentUserType != null && currentUserType != _employeeUserType) {
      await logout();
      throw ApiException(_loginFailedMessage);
    }

    final employee = await _currentEmployee();
    if (employee == null) {
      await logout();
      throw ApiException(_loginFailedMessage);
    }

    final authUserId = authResult.user?.id ?? _client.auth.currentUser?.id;
    final employeeId = employee['id'];
    if (authUserId != null && authUserId.isNotEmpty && employeeId != null) {
      await _syncEmployeeAuthId(employeeId: employeeId, authUserId: authUserId);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore logout errors and clear local state below.
    } finally {
      _fallbackAuthenticated = false;
      _user = null;
    }
  }

  @override
  Future<Map<String, dynamic>> getDashboard() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final employeeId = _toIntId(employee['id']);
    if (employeeId == null) {
      throw ApiException('Employee profile not found.');
    }

    final attendanceRows = await _client
        .from('attendance_records')
        .select('status')
        .eq('employee_id', employeeId);

    final leaveBalances = await _client
        .from('leave_balances')
        .select('id,remaining_days')
        .eq('employee_id', employeeId);

    final leaveRequests = await _client
        .from('leave_requests')
        .select('id,status')
        .eq('employee_id', employeeId);

    final credentialIdentifiers = _employeeCredentialIdentifiers(employee);
    final credentialRows = await _queryEmployeeCredentials(
      select: 'id,status,credential_type,expires_at,created_at',
      employeeIdentifiers: credentialIdentifiers,
    );

    final notificationItems = await getNotifications();

    final attendanceSummary = <String, int>{
      'present': 0,
      'absent': 0,
      'on_leave': 0,
    };

    for (final row in attendanceRows.whereType<Map>()) {
      final status = (row['status'] ?? '').toString();
      if (attendanceSummary.containsKey(status)) {
        attendanceSummary[status] = (attendanceSummary[status] ?? 0) + 1;
      }
    }

    final pending = leaveRequests
        .whereType<Map>()
        .where((row) => (row['status'] ?? '').toString() == 'pending')
        .length;

    final nonCompliantStatuses = <String>{
      'expired',
      'rejected',
      'invalid',
      'non-compliant',
      'non_compliant',
    };

    bool isApprovedCredential(Map row) {
      final status = (row['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
      return status.isEmpty ||
        status == 'verified' ||
        status == 'approved' ||
        status == 'active' ||
        status == 'compliant' ||
        status == 'valid';
    }

    bool isExpiredCredential(Map row) {
      final rawType = (row['credential_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final status = (row['status'] ?? '').toString().trim().toLowerCase();
      if (nonCompliantStatuses.contains(status)) {
        return true;
      }

      final expiresAtRaw = (row['expires_at'] ?? '').toString().trim();
      final createdAtRaw = (row['created_at'] ?? '').toString().trim();
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      final createdAt = DateTime.tryParse(createdAtRaw);

      DateTime? effectiveExpiresAt;
      if (rawType == 'resume' || rawType.contains('resume')) {
        if (expiresAt != null &&
            createdAt != null &&
            expiresAt.year == createdAt.year &&
            expiresAt.month == createdAt.month &&
            expiresAt.day == createdAt.day) {
          effectiveExpiresAt = DateTime(
            createdAt.year + 1,
            createdAt.month,
            createdAt.day,
          );
        } else {
          effectiveExpiresAt =
              expiresAt ?? createdAt?.add(const Duration(days: 365));
        }
      } else if (rawType == 'prc' || rawType.contains('prc license')) {
        effectiveExpiresAt = expiresAt;
      } else {
        effectiveExpiresAt = expiresAt;
      }

      if (effectiveExpiresAt == null) {
        return false;
      }

      final now = DateTime.now();
      return effectiveExpiresAt.isBefore(
        DateTime(now.year, now.month, now.day),
      );
    }

    bool isExpiringSoonCredential(Map row) {
      final rawType = (row['credential_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final thresholdDays = rawType == 'resume' || rawType.contains('resume')
          ? 30
          : rawType == 'prc' || rawType.contains('prc license')
          ? 90
          : null;
      if (thresholdDays == null) {
        return false;
      }

      final expiresAtRaw = (row['expires_at'] ?? '').toString().trim();
      final createdAtRaw = (row['created_at'] ?? '').toString().trim();
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      final createdAt = DateTime.tryParse(createdAtRaw);

      DateTime? effectiveExpiresAt;
      if (rawType == 'resume' || rawType.contains('resume')) {
        if (expiresAt != null &&
            createdAt != null &&
            expiresAt.year == createdAt.year &&
            expiresAt.month == createdAt.month &&
            expiresAt.day == createdAt.day) {
          effectiveExpiresAt = DateTime(
            createdAt.year + 1,
            createdAt.month,
            createdAt.day,
          );
        } else {
          effectiveExpiresAt =
              expiresAt ?? createdAt?.add(const Duration(days: 365));
        }
      } else {
        effectiveExpiresAt = expiresAt;
      }

      if (effectiveExpiresAt == null) {
        return false;
      }

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      if (effectiveExpiresAt.isBefore(startOfToday)) {
        return false;
      }

      final warningEnd = startOfToday.add(Duration(days: thresholdDays));
      return !effectiveExpiresAt.isAfter(warningEnd);
    }

    final activeCredentials = credentialRows.whereType<Map>().where((row) {
      final item = row.cast<String, dynamic>();
      return isApprovedCredential(item) && !isExpiredCredential(item);
    }).length;

    final expiringSoon = credentialRows.whereType<Map>().where((row) {
      final item = row.cast<String, dynamic>();
      return isApprovedCredential(item) && isExpiringSoonCredential(item);
    }).length;

    final pendingReviewCredentials = credentialRows.whereType<Map>().where((
      row,
    ) {
      final status = (row['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return status == 'pending';
    }).length;

    final compliantCredentials = credentialRows.whereType<Map>().where((row) {
      final item = row.cast<String, dynamic>();
      return isApprovedCredential(item) && !isExpiredCredential(item);
    }).length;

    final nonCompliantCredentials = credentialRows.whereType<Map>().where((
      row,
    ) {
      final item = row.cast<String, dynamic>();
      return !isApprovedCredential(item) || isExpiredCredential(item);
    }).length;

    final unreadNotifications = notificationItems
      .where((row) => row['isRead'] != true)
      .length;

    final totalLeaveDays = leaveBalances.whereType<Map>().fold<double>(0, (
      sum,
      row,
    ) {
      final value = row['remaining_days'];
      if (value is num) {
        return sum + value.toDouble();
      }
      return sum + (double.tryParse(value?.toString() ?? '') ?? 0);
    });

    return {
      'employee': employee,
      'attendance_summary': attendanceSummary,
      'leave_summary': {
        'balance_count': leaveBalances.length,
        'request_count': leaveRequests.length,
        'pending_requests': pending,
        'total_days_remaining': totalLeaveDays,
      },
      'credentials_summary': {
        'total_count': credentialRows.length,
        'active_count': activeCredentials,
        'pending_review_count': pendingReviewCredentials,
        'expiring_soon_count': expiringSoon,
        'non_compliant_count': nonCompliantCredentials,
        'compliant_count': compliantCredentials,
      },
      'notifications_summary': {
        'total_count': notificationItems.length,
        'unread_count': unreadNotifications,
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceDtr() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final numericEmployeeId = _toIntId(employee['id']);
    if (numericEmployeeId == null) {
      throw ApiException('Employee profile not found.');
    }

    final rows = await _client
        .from('attendance_records')
        .select(
          'id,record_date,time_in,time_out,scheduled_time_in,scheduled_time_out,tardiness_minutes,undertime_minutes,overtime_minutes,status,schedule_status,schedule_notes',
        )
        .eq('employee_id', numericEmployeeId)
        .order('record_date', ascending: false);

    return _toMapList(rows);
  }

  @override
  Future<Map<String, dynamic>?> getCurrentEmployeeScheduleSubmission() async {
    final employee = await _currentEmployee();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }

    final numericEmployeeId = _toIntId(employee['id']);
    if (numericEmployeeId == null) {
      throw ApiException('Employee profile not found.');
    }

    final submissionRows = await _client
        .from('employee_schedule_submissions')
        .select(
          'id,employee_id,term_label,semester_label,status,submitted_at,reviewed_at,review_notes,is_current',
        )
        .eq('employee_id', numericEmployeeId)
        .order('submitted_at', ascending: false)
        .limit(1);

    final submissionList = _toMapList(submissionRows);
    if (submissionList.isEmpty) {
      return null;
    }

    final submission = submissionList.first.cast<String, dynamic>();
    final submissionId = submission['id'];

    final dayRows = await _client
        .from('employee_schedule_days')
        .select('day_name,day_index,has_work,time_in,time_out')
        .eq('schedule_submission_id', submissionId)
        .order('day_index', ascending: true);

    return {
      'submission': submission,
      'days': _toMapList(dayRows),
    };
  }

  @override
  Future<Map<String, dynamic>> submitEmployeeSchedule({
    required String termLabel,
    required List<Map<String, dynamic>> days,
  }) async {
    final employee = await _currentEmployee();
    final user = await _currentUserRow();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    final normalizedTerm = termLabel.trim();
    if (normalizedTerm.isEmpty) {
      throw ApiException('Term is required.');
    }

    // Normalize term labels to canonical "Term" form so web and mobile match.
    // e.g. convert "3rd Semester" -> "3rd Term"
    final canonicalTerm = normalizedTerm.replaceAll(
      RegExp(r'Semester', caseSensitive: false),
      'Term',
    );

    if (days.isEmpty) {
      throw ApiException('At least one schedule day is required.');
    }

    final employeeId = _toIntId(employee['id']);
    final submittedBy = _toIntId(user['id']);
    if (employeeId == null || submittedBy == null) {
      throw ApiException('Employee or user profile not found.');
    }
    final submittedAt = DateTime.now().toUtc().toIso8601String();

    late int submissionId;
    try {
      final submissionRows = await _client
          .from('employee_schedule_submissions')
          .insert({
            'employee_id': employeeId,
            'submitted_by': submittedBy,
            'semester_label': canonicalTerm,
            'term_label': canonicalTerm,
            'status': 'pending',
            'submitted_at': submittedAt,
            'is_current': false,
          })
          .select('id');

      final submissionList = _toMapList(submissionRows);
      if (submissionList.isEmpty || submissionList.first['id'] == null) {
        throw ApiException(
          'Schedule submission failed: unable to create header row.',
        );
      }

      submissionId = submissionList.first['id'] as int;
    } on PostgrestException catch (error) {
      throw ApiException(
        'Failed to create schedule submission header (RLS/permission issue?): ${error.message}',
      );
    } catch (error) {
      throw ApiException('Failed to create schedule submission header: $error');
    }

    final dayRows = days.map((day) {
      final hasWork = day['has_work'] == true;
      return <String, dynamic>{
        'schedule_submission_id': submissionId,
        'day_name': (day['day_name'] ?? '').toString(),
        'day_index': day['day_index'],
        'has_work': hasWork,
        'time_in': hasWork ? day['time_in'] : null,
        'time_out': hasWork ? day['time_out'] : null,
      };
    }).toList();

    try {
      await _client.from('employee_schedule_days').insert(dayRows);
    } on PostgrestException catch (error) {
      throw ApiException(
        'Failed to save schedule days (RLS/permission issue?): ${error.message}',
      );
    } catch (error) {
      throw ApiException('Failed to save schedule days: $error');
    }

    return {
      'message': 'Schedule submitted successfully.',
      'submission_id': submissionId,
      'term_label': normalizedTerm,
      'day_count': dayRows.length,
    };
  }

  @override
  Future<Map<String, dynamic>> getLeaveMonitoring() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final employeeId = _toIntId(employee['id']);
    if (employeeId == null) {
      throw ApiException('Employee profile not found.');
    }
    final balances = await _client
        .from('leave_balances')
        .select(
          'id,employee_id,leave_type,remaining_days,created_at,updated_at',
        )
        .eq('employee_id', employeeId);
    final sortedBalances = _toMapList(balances)
      ..sort((left, right) {
        final leftUpdated = DateTime.tryParse(
              (left['updated_at'] ?? left['created_at'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rightUpdated = DateTime.tryParse(
              (right['updated_at'] ?? right['created_at'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return rightUpdated.compareTo(leftUpdated);
      });

    final requests = await _client
        .from('leave_requests')
        .select(
          'id,employee_id,leave_type,start_date,end_date,days_deducted,status,cutoff_date,reason,created_at,updated_at',
        )
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    return {
      'balances': sortedBalances,
      'requests': _toMapList(requests),
    };
  }

  Future<Map<String, dynamic>> getSupabaseHealth() async {
    try {
      final rows = await _client.from('users').select('id').limit(1);
      return {
        'connected': true,
        'message': 'Supabase direct read is working.',
        'table': 'users',
        'row_count': rows.length,
      };
    } catch (error) {
      throw ApiException(error.toString());
    }
  }

  Future<Map<String, dynamic>> getSupabaseSummary() async {
    const tables = [
      'users',
      'employees',
      'employee_credentials',
      'announcements',
    ];
    final counts = <String, int>{};
    final errors = <String, String>{};

    for (final table in tables) {
      try {
        final rows = await _client.from(table).select('id');
        counts[table] = rows.length;
      } catch (error) {
        errors[table] = error.toString();
      }
    }

    if (counts.isEmpty) {
      throw ApiException('Unable to load Supabase summary.');
    }

    return {
      'connected': true,
      'message': 'Supabase summary loaded.',
      'counts': counts,
      if (errors.isNotEmpty) 'errors': errors,
    };
  }

  @override
  Future<List<AcademicCalendarEntry>> getAcademicCalendarEntries() async {
    final baseUrl = AppConfig.laravelBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw ApiException(
        'Academic Calendar API is not configured. Set LARAVEL_BASE_URL.',
      );
    }

    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBaseUrl/api/academic-calendar');

    late http.Response response;
    try {
      response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } catch (error) {
      throw ApiException('Failed to load Academic Calendar: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Academic Calendar request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('Academic Calendar API returned an invalid payload.');
    }

    final entries = decoded
        .whereType<Map>()
        .map((row) => AcademicCalendarEntry.fromJson(
              row.cast<String, dynamic>(),
            ))
        .toList()
      ..sort((left, right) => left.eventDate.compareTo(right.eventDate));

    return entries;
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    final employee = await _currentEmployee();

    final notificationUserIds = <int>{};

    final currentUserId = _toIntId(user['id']);
    if (currentUserId != null) {
      notificationUserIds.add(currentUserId);
    }

    final employeeUserId = _toIntId(employee?['user_id']);
    if (employeeUserId != null) {
      notificationUserIds.add(employeeUserId);
    }

    if (notificationUserIds.isEmpty) {
      debugPrint('🔔 Notifications: no user IDs resolved.');
      return const [];
    }

    debugPrint(
      '🔔 Notifications: loading for user IDs ${notificationUserIds.toList()}',
    );

    try {
      // ============================================================
      // STEP 1: Load notification rows first.
      // ============================================================
      final notificationRows = await _client
          .from('announcement_notifications')
          .select(
            'id,user_id,announcement_id,is_read,read_at,created_at,updated_at,redirect_url',
          )
          .inFilter('user_id', notificationUserIds.toList())
          .order('created_at', ascending: false);

      final notifications = _toMapList(notificationRows);

      debugPrint(
        '📥 Notification rows loaded: ${notifications.length}',
      );

      debugPrint('🔔 ===== NOTIFICATION ROWS =====');
      for (final notification in notifications) {
        debugPrint(
          '🔔 ID: ${notification['id']} | '
          'USER: ${notification['user_id']} | '
          'ANNOUNCEMENT: ${notification['announcement_id']} | '
          'READ: ${notification['is_read']} | '
          'CREATED: ${notification['created_at']}',
        );
      }
      debugPrint('🔔 =============================');

      if (notifications.isEmpty) {
        debugPrint('📭 No notification rows found.');
        return const [];
      }

      // ============================================================
      // STEP 2: Collect announcement IDs.
      // ============================================================
      final announcementIds = <int>{};

      for (final notification in notifications) {
        final announcementId = _toIntId(notification['announcement_id']);
        if (announcementId != null) {
          announcementIds.add(announcementId);
        }
      }

      debugPrint(
        '📢 Announcement IDs found: ${announcementIds.toList()}',
      );

      if (announcementIds.isEmpty) {
        return notifications;
      }

      // ============================================================
      // STEP 3: Load announcements separately.
      // ============================================================
      final announcementRows = await _client
          .from('announcements')
          .select(
            'id,title,content,priority,target_office,published_at,created_at,is_published,deleted_at,expires_at',
          )
          .inFilter('id', announcementIds.toList());

      final announcements = _toMapList(announcementRows);

      debugPrint(
        '📢 Announcements loaded: ${announcements.length}',
      );

      debugPrint('📢 ===== ANNOUNCEMENT ROWS =====');
      for (final announcement in announcements) {
        debugPrint(
          '📢 ID: ${announcement['id']} | '
          'TITLE: ${announcement['title']} | '
          'PUBLISHED: ${announcement['is_published']} | '
          'DELETED: ${announcement['deleted_at']} | '
          'EXPIRES: ${announcement['expires_at']}',
        );
      }
      debugPrint('📢 =============================');

      final announcementMap = <int, Map<String, dynamic>>{};

      for (final announcement in announcements) {
        final id = _toIntId(announcement['id']);
        if (id != null) {
          announcementMap[id] = announcement;
        }
      }

      // ============================================================
      // STEP 4: Attach announcements to notifications.
      // ============================================================
      final results = <Map<String, dynamic>>[];

      for (final notification in notifications) {
        final notificationId = _toIntId(notification['id']);
        final announcementId = _toIntId(notification['announcement_id']);

        debugPrint(
          '🔍 Processing notification $notificationId '
          '→ announcement $announcementId',
        );

        if (announcementId == null) {
          debugPrint(
            '⚠️ Notification $notificationId has no announcement_id.',
          );
          final item = Map<String, dynamic>.from(notification);
          item['announcement'] = <String, dynamic>{
            'title': 'Announcement',
            'content': '',
            'priority': 'medium',
          };
          results.add(item);
          continue;
        }

        Map<String, dynamic>? announcement = announcementMap[announcementId];

        // Fallback: if the bulk query did not return the announcement,
        // try fetching that exact announcement by ID.
        if (announcement == null) {
          debugPrint(
            '⚠️ Announcement $announcementId was not returned by bulk query. '
            'Trying direct lookup...',
          );

          try {
            final fallbackRows = await _client
                .from('announcements')
                .select(
                  'id,title,content,priority,target_office,published_at,created_at,is_published,deleted_at,expires_at',
                )
                .eq('id', announcementId)
                .limit(1);

            final fallbackList = _toMapList(fallbackRows);

            if (fallbackList.isNotEmpty) {
              announcement = fallbackList.first;
              debugPrint(
                '✅ Direct lookup found announcement $announcementId: '
                '${announcement['title']}',
              );
            }
          } catch (error) {
            debugPrint(
              '❌ Direct announcement lookup failed for $announcementId: $error',
            );
          }
        }

        if (announcement == null) {
          debugPrint(
            '❌ Announcement $announcementId does not exist or is not readable. '
            'Using fallback announcement payload.',
          );
        }

        // announcement_notifications is the source of truth that the user
        // received a notification, even if announcement metadata is unreadable.
        final item = Map<String, dynamic>.from(notification);
        item['announcement'] = announcement != null
            ? Map<String, dynamic>.from(announcement)
            : <String, dynamic>{
                'title': 'Announcement',
                'content': '',
                'priority': 'medium',
              };
        results.add(item);

        debugPrint(
          '✅ ADDED notification $notificationId '
          '→ announcement $announcementId '
          '→ "${item['announcement']?['title']}"',
        );
      }

      debugPrint(
        '🎉 Notifications returned to Flutter: ${results.length}',
      );

      debugPrint('📋 ===== FINAL NOTIFICATIONS =====');
      for (final item in results) {
        debugPrint(
          '📋 Notification ${item['id']} → '
          'User ${item['user_id']} → '
          'Announcement ${item['announcement_id']} → '
          '${item['announcement']?['title']} → '
          'Read: ${item['is_read']}',
        );
      }
      debugPrint('📋 ================================');

      return results;
    } on PostgrestException catch (error) {
      debugPrint(
        '❌ Notification query failed: ${error.message} (${error.code})',
      );
      throw ApiException(
        'Failed to load notifications: ${error.message}',
      );
    } catch (error) {
      debugPrint(
        '❌ Failed to load notifications: $error',
      );
      throw ApiException(
        'Failed to load notifications: $error',
      );
    }
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    try {
      int? numericUserId = _toIntId(user['id']);
      if (numericUserId == null) {
        final employee = await _currentEmployee();
        numericUserId = _toIntId(employee?['user_id']);
      }

      if (numericUserId == null) {
        return; // nothing to mark
      }

      await _client
          .from('announcement_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', numericUserId);
    } catch (error) {
      throw ApiException('Failed to mark notifications read: $error');
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    try {
      int? numericUserId = _toIntId(user['id']);
      if (numericUserId == null) {
        final employee = await _currentEmployee();
        numericUserId = _toIntId(employee?['user_id']);
      }

      if (numericUserId == null) {
        return; // nothing to mark
      }

      await _client
          .from('announcement_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId)
          .eq('user_id', numericUserId);
    } catch (error) {
      throw ApiException('Failed to mark notification read: $error');
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    try {
      int? numericUserId = _toIntId(user['id']);
      if (numericUserId == null) {
        final employee = await _currentEmployee();
        numericUserId = _toIntId(employee?['user_id']);
      }

      if (numericUserId == null) {
        return; // nothing to clear
      }

      await _client
          .from('announcement_notifications')
          .delete()
          .eq('user_id', numericUserId);
    } catch (error) {
      throw ApiException('Failed to clear notifications: $error');
    }
  }

  @override
  Future<Map<String, dynamic>> getAccount() async {
    final user = await _currentUserRow();
    final employee = await _currentEmployee();

    return {'user': user, 'employee': employee};
  }

  @override
  Future<Map<String, dynamic>> updateAccount(
    Map<String, dynamic> payload,
  ) async {
    final user = await _currentUserRow();
    if (user == null) {
      throw ApiException('User profile not found.');
    }

    final userId = user['id'];
    if (userId != null) {
      final update = <String, dynamic>{};
      if (payload.containsKey('name')) {
        update['name'] = payload['name'];
      }
      if (payload.containsKey('email')) {
        update['email'] = payload['email'];
      }
      if (update.isNotEmpty) {
        final numericUserId = _toIntId(userId);
        if (numericUserId != null) {
          await _client.from('users').update(update).eq('id', numericUserId);
        }
      }
    }

    final employee = await _currentEmployee();
    if (employee != null && employee['id'] != null) {
      final employeeUpdate = <String, dynamic>{};
      if (payload.containsKey('phone')) {
        employeeUpdate['phone'] = payload['phone'];
      }
      if (payload.containsKey('address')) {
        employeeUpdate['address'] = payload['address'];
      }
      if (payload.containsKey('employment_type')) {
        employeeUpdate['employment_type'] = payload['employment_type'];
      }
      if (employeeUpdate.isNotEmpty) {
        final numericEmployeeId = _toIntId(employee['id']);
        if (numericEmployeeId != null) {
          await _client
              .from('employees')
              .update(employeeUpdate)
              .eq('id', numericEmployeeId);
        }
      }
    }

    final refreshed = await getAccount();
    return {'message': 'Account updated successfully.', ...refreshed};
  }

  @override
  Future<Map<String, String>> uploadProfilePhoto({
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ApiException('Selected photo file was not found.');
    }

    final bytes = await file.readAsBytes();
    final authUid = (_client.auth.currentUser?.id ?? '').trim();

    if (authUid.isEmpty) {
      throw ApiException(
        'Profile photo upload requires an authenticated Supabase session. Please sign in again.',
      );
    }

    const contentType = 'image/jpeg';
    StorageException? lastMissingBucketError;
    StorageException? lastPolicyDeniedError;
    Exception? lastOtherError;

    final filePathOnBucket = '$authUid/avatar.jpg';
    try {
      await _client.storage
          .from(_profilePhotoBucket)
          .uploadBinary(
            filePathOnBucket,
            bytes,
            fileOptions: const FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final savedPath = '$_profilePhotoPathPrefix$filePathOnBucket';
      await _persistProfilePhotoPath(savedPath);

      final publicUrl = _client.storage
          .from(_profilePhotoBucket)
          .getPublicUrl(filePathOnBucket);

      return {'path': savedPath, 'url': publicUrl};
    } on StorageException catch (error) {
      final msg = error.message.toLowerCase();
      final isMissingBucket =
          msg.contains('bucket not found') ||
          msg.contains('bucket does not exist') ||
          (msg.contains('does not exist') && msg.contains('bucket'));
      if (isMissingBucket) {
        lastMissingBucketError = error;
      } else if (msg.contains('row-level security') ||
          msg.contains('not authorized') ||
          msg.contains('permission denied') ||
          msg.contains('violates')) {
        lastPolicyDeniedError = error;
      } else {
        lastOtherError = error;
      }
    } catch (error) {
      lastOtherError = Exception(error.toString());
    }

    if (lastPolicyDeniedError != null) {
      throw ApiException(
        'Profile photo upload failed: ${lastPolicyDeniedError.message}. The bucket exists but RLS denied the upload. Check INSERT policy for storage.objects and ensure the upload path/prefix is allowed.',
      );
    }

    if (lastMissingBucketError != null) {
      final bucketNames = _profilePhotoBuckets.join(', ');
      throw ApiException(
        'Profile photo upload failed: ${lastMissingBucketError.message}. Check storage bucket names: $bucketNames.',
      );
    }

    if (lastOtherError != null) {
      throw ApiException('Profile photo upload failed: $lastOtherError');
    }

    throw ApiException(
      'Profile photo upload failed: unable to upload the selected file.',
    );
  }

  @override
  Future<String?> getProfilePhotoUrl() async {
    final user = await _currentUserRow();
    final employee = await _currentEmployee();

    Map<String, dynamic> userRow = user ?? <String, dynamic>{};
    Map<String, dynamic> employeeRow = employee ?? <String, dynamic>{};

    if (user?['id'] != null) {
      try {
        final rows = await _client
            .from('users')
            .select('*')
            .eq('id', user!['id'])
            .limit(1);
        final list = _toMapList(rows);
        if (list.isNotEmpty) {
          userRow = list.first;
        }
      } catch (_) {
        // Best effort only.
      }
    }

    if (employee?['id'] != null) {
      try {
        final rows = await _client
            .from('employees')
            .select('*')
            .eq('id', employee!['id'])
            .limit(1);
        final list = _toMapList(rows);
        if (list.isNotEmpty) {
          employeeRow = list.first;
        }
      } catch (_) {
        // Best effort only.
      }
    }

    final storedPath = _extractProfilePhotoPath(userRow, employeeRow);
    if (storedPath != null) {
      final url = await _tryCreateSignedUrlFromStoredPath(storedPath);
      if (url != null) {
        return url;
      }
    }

    final authUid = (_client.auth.currentUser?.id ?? '').trim();
    final userId = (user?['id'] ?? '').toString().trim();
    final employeeId = (employee?['id'] ?? '').toString().trim();
    final prefixes = <String>{
      if (employeeId.isNotEmpty) 'employee-$employeeId',
      if (userId.isNotEmpty) 'user-$userId',
      if (authUid.isNotEmpty) authUid,
      if (userId.isNotEmpty) userId,
    };

    const extensions = ['jpg', 'jpeg', 'png'];
    const fileNames = ['avatar', 'profile'];

    for (final bucket in _profilePhotoBuckets) {
      for (final prefix in prefixes) {
        for (final fileName in fileNames) {
          for (final ext in extensions) {
            final path = '$prefix/$fileName.$ext';
            try {
              return await _client.storage
                  .from(bucket)
                  .createSignedUrl(path, 60 * 60 * 24 * 30);
            } catch (_) {
              // Try next candidate.
            }
          }
        }
      }
    }

    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeCredentials() async {
    final employee = await _currentEmployee();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }

    final credentialIdentifiers = _employeeCredentialIdentifiers(employee);
    final rows = await _queryEmployeeCredentials(
      select:
          'id,employee_id,credential_type,title,department_id,expires_at,description,file_path,status,review_notes,created_at,updated_at',
      employeeIdentifiers: credentialIdentifiers,
      orderByCreatedAtDesc: true,
    );

    return _toMapList(rows);
  }

  @override
  Future<String?> getCredentialFileUrl(String storedPath) async {
    final normalized = storedPath.trim();
    if (normalized.isEmpty) return null;

    // If it's already a full URL, return it.
    final uri = Uri.tryParse(normalized);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return normalized;
    }

    // Reuse existing logic for common stored-path patterns (profile photo style).
    final fromProfile = await _tryCreateSignedUrlFromStoredPath(normalized);
    if (fromProfile != null) return fromProfile;

    // Try to parse as "bucket/object" if a slash exists.
    final firstSlash = normalized.indexOf('/');
    if (firstSlash > 0 && firstSlash < normalized.length - 1) {
      final possibleBucket = normalized.substring(0, firstSlash);
      final object = normalized.substring(firstSlash + 1);

      // If the first part looks like a bucket name (in our list), try it.
      final possibleBucketLower = possibleBucket.toLowerCase();
      if (_credentialFilesBuckets.map((b) => b.toLowerCase()).contains(possibleBucketLower)) {
        try {
          return _client.storage.from(possibleBucketLower).getPublicUrl(object);
        } catch (_) {
          try {
            return await _client.storage
                .from(possibleBucketLower)
                .createSignedUrl(object, 60 * 60 * 24 * 30);
          } catch (_) {
            // Fallback to trying other buckets below
          }
        }
      }
    }

    // Try the entire path across all known credential buckets.
    // This handles cases where the stored path is "employee-XX/timestamp_file.pdf"
    // and doesn't include a bucket prefix.
    for (final bucket in _credentialFilesBuckets) {
      final bucketName = bucket.toLowerCase();
      try {
        // Try public URL first (faster)
        return _client.storage.from(bucketName).getPublicUrl(normalized);
      } catch (_) {
        // Try next bucket
      }
    }

    // Last resort: try signed URLs in case RLS blocks public access
    for (final bucket in _credentialFilesBuckets) {
      final bucketName = bucket.toLowerCase();
      try {
        return await _client.storage
            .from(bucketName)
            .createSignedUrl(normalized, 60 * 60 * 24 * 30);
      } catch (_) {
        // Try next bucket
      }
    }

    return null;
  }

  @override
  Future<void> deleteEmployeeCredential({
    required dynamic id,
    String? filePath,
  }) async {
    try {
      await _client.from('employee_credentials').delete().eq('id', id);
    } catch (error) {
      throw ApiException('Failed to delete credential: $error');
    }

    final deletedFilePath = (filePath ?? '').toString().trim();
    if (deletedFilePath.isEmpty) {
      return;
    }

    if (deletedFilePath.startsWith('http://') ||
        deletedFilePath.startsWith('https://')) {
      return;
    }

    final normalized = deletedFilePath;
    final slash = normalized.indexOf('/');
    if (slash <= 0 || slash >= normalized.length - 1) {
      return;
    }

    final maybeBucket = normalized.substring(0, slash);
    final objectTail = normalized.substring(slash + 1);

    final targetBuckets = <String>[];
    if (_credentialFilesBuckets.contains(maybeBucket)) {
      targetBuckets.add(maybeBucket);
    }
    for (final bucket in _credentialFilesBuckets) {
      if (!targetBuckets.contains(bucket)) {
        targetBuckets.add(bucket);
      }
    }

    for (final bucket in targetBuckets) {
      final objectPath = bucket == maybeBucket ? objectTail : normalized;
      try {
        await _client.storage.from(bucket).remove([objectPath]);
        break;
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  @override
  Future<Map<String, dynamic>> createEmployeeCredential(
    Map<String, dynamic> payload,
  ) async {
    Future<Map<String, dynamic>> insertWithPayload(
      Map<String, dynamic> insertPayload,
    ) async {
      await _client.from('employee_credentials').insert(insertPayload);
      return Map<String, dynamic>.from(insertPayload);
    }

    try {
      return await insertWithPayload(payload);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final isPolicyDenied =
          error.code == '42501' || message.contains('row-level security');
      if (!isPolicyDenied) {
        rethrow;
      }

      final employee = await _currentEmployee();
      final attempted = (payload['employee_id'] ?? '').toString().trim();
      final fallbackIds = <dynamic>[];
      final seen = <String>{attempted};

      void addFallback(dynamic value) {
        if (value == null) {
          return;
        }
        final text = value.toString().trim();
        if (text.isEmpty || seen.contains(text)) {
          return;
        }
        seen.add(text);
        fallbackIds.add(value);
      }

      addFallback(employee?['employee_id']);
      addFallback(employee?['id']);

      for (final fallbackId in fallbackIds) {
        final fallbackPayload = Map<String, dynamic>.from(payload)
          ..['employee_id'] = fallbackId;
        try {
          return await insertWithPayload(fallbackPayload);
        } on PostgrestException catch (fallbackError) {
          final fallbackMessage = fallbackError.message.toLowerCase();
          final stillPolicyDenied =
              fallbackError.code == '42501' ||
              fallbackMessage.contains('row-level security');
          if (!stillPolicyDenied) {
            rethrow;
          }
        }
      }

      throw ApiException(
        'Credential insert failed: ${error.message}. The row was blocked by RLS on employee_credentials.',
      );
    }
  }

  @override
  Future<String> uploadEmployeeCredentialFile({
    required dynamic employeeId,
    dynamic employeeAlternateId,
    required Uint8List fileBytes,
    required String originalFileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = originalFileName.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final user = await _currentUserRow();
    final authUid = (_client.auth.currentUser?.id ?? '').trim();
    final userId = (user?['id'] ?? '').toString().trim();

    print('DEBUG uploadEmployeeCredentialFile:');
    print('  currentUser: ${_client.auth.currentUser?.email}');
    print('  authUid: "$authUid"');
    print('  userId: "$userId"');
    print('  employeeId: "$employeeId"');

    final candidatePrefixes = <String>{
      'employee-$employeeId',
      'employee_$employeeId',
      if (employeeAlternateId != null)
        'employee-${employeeAlternateId.toString().trim()}',
      if (employeeAlternateId != null)
        'employee_${employeeAlternateId.toString().trim()}',
      if (authUid.isNotEmpty) authUid,
      if (userId.isNotEmpty) 'user-$userId',
      if (userId.isNotEmpty) userId,
    }.toList();
    print('  candidatePrefixes: $candidatePrefixes');

    final contentType = _contentTypeFromFileName(safeName);

    StorageException? lastMissingBucketError;
    StorageException? lastPolicyDeniedError;

    for (final bucket in _credentialFilesBuckets) {
      final bucketName = bucket.toLowerCase();
      for (final prefix in candidatePrefixes) {
        final filePath = '$prefix/${timestamp}_$safeName';
        try {
          await _client.storage
              .from(bucketName)
              .uploadBinary(
                filePath,
                fileBytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: false,
                ),
              );
          return '$bucketName/$filePath';
        } on StorageException catch (error) {
          final message = error.message.toLowerCase();
          final isMissingBucket =
              message.contains('bucket not found') ||
              message.contains('not found') ||
              message.contains('does not exist');
          final isPolicyDenied =
              message.contains('row-level security') ||
              message.contains('violates') ||
              message.contains('not authorized') ||
              message.contains('permission denied');

          if (isMissingBucket) {
            lastMissingBucketError = error;
            // No need to try other prefixes if bucket itself is missing.
            break;
          }

          if (isPolicyDenied) {
            lastPolicyDeniedError = error;
            continue;
          }

          throw ApiException('File upload failed: ${error.message}');
        } catch (error) {
          throw ApiException('File upload failed: $error');
        }
      }
    }

    if (lastPolicyDeniedError != null) {
      throw ApiException(
        'File upload failed: ${lastPolicyDeniedError.message}. The bucket exists but RLS denied the upload. Check INSERT policy for storage.objects.',
      );
    }

    if (lastMissingBucketError != null) {
      throw ApiException(
        'File upload failed: ${lastMissingBucketError.message}. Check storage bucket name for: ${_credentialFilesBuckets.join(', ')}.',
      );
    }

    throw ApiException(
      'File upload failed: unable to upload the selected file.',
    );
  }

  @override
  Future<Map<String, dynamic>> submitWfhMonitoring({
    required dynamic employeeId,
    required String wfhDate,
    String? timeIn,
    String? timeOut,
    required String filePath,
  }) async {
    // Get the current user to populate submitted_by
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User not authenticated.');
    }

    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'employee_id': employeeId,
      'submitted_by': user['id'],
      'wfh_date': wfhDate,
      'time_in': timeIn,
      'time_out': timeOut,
      'file_path': filePath,
      'status': 'pending',
      'submitted_at': now,
      'created_at': now,
      'updated_at': now,
    };

    try {
      final rows = await _client
          .from('wfh_monitoring_submissions')
          .insert(payload)
          .select('id')
          .limit(1);
      final list = _toMapList(rows);
      final insertedId = list.isNotEmpty ? list.first['id'] : null;
      return {'id': insertedId, 'message': 'Submission saved.'};
    } catch (error) {
      throw ApiException('Failed to save WFH monitoring submission: $error');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWfhMonitoringSubmissions() async {
    final employee = await _currentEmployee();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }

    final employeeId = _toIntId(employee['id']);
    if (employeeId == null) {
      throw ApiException('Employee profile not found.');
    }

    try {
      final rows = await _client
          .from('wfh_monitoring_submissions')
          .select('*')
          .eq('employee_id', employeeId)
          .order('submitted_at', ascending: false);
      return _toMapList(rows);
    } catch (error) {
      throw ApiException('Failed to fetch WFH monitoring submissions: $error');
    }
  }

  String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  String? _extractProfilePhotoPath(
    Map<String, dynamic> user,
    Map<String, dynamic> employee,
  ) {
    const keys = [
      'profilephoto_path',
      'profile_photo_path',
      'profile_image_path',
      'avatar_path',
      'photo_path',
      'image_path',
      'profile_photo',
      'avatar_url',
      'photo_url',
      'image_url',
    ];

    for (final key in keys) {
      final employeeValue = (employee[key] ?? '').toString().trim();
      if (employeeValue.isNotEmpty) {
        return employeeValue;
      }

      final userValue = (user[key] ?? '').toString().trim();
      if (userValue.isNotEmpty) {
        return userValue;
      }
    }

    return null;
  }

  Future<String?> _tryCreateSignedUrlFromStoredPath(String storedPath) async {
    final normalized = storedPath.trim();
    if (normalized.isEmpty) {
      return null;
    }

    // If DB already stores a complete URL, use it directly.
    final uri = Uri.tryParse(normalized);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
      return normalized;
    }

    // Accept Supabase public object paths like:
    // /storage/v1/object/public/<bucket>/<object>
    const publicObjectPrefix = '/storage/v1/object/public/';
    final publicIdx = normalized.indexOf(publicObjectPrefix);
    if (publicIdx >= 0) {
      final tail = normalized.substring(publicIdx + publicObjectPrefix.length);
      final slash = tail.indexOf('/');
      if (slash > 0 && slash < tail.length - 1) {
        final bucket = tail.substring(0, slash);
        final objectPath = tail.substring(slash + 1);
        try {
          return _client.storage.from(bucket).getPublicUrl(objectPath);
        } catch (_) {
          // Continue to other formats.
        }
      }
    }

    if (normalized.startsWith('public/')) {
      final tail = normalized.substring('public/'.length);
      final slash = tail.indexOf('/');
      if (slash > 0 && slash < tail.length - 1) {
        final bucket = tail.substring(0, slash);
        final objectPath = tail.substring(slash + 1);
        try {
          return _client.storage.from(bucket).getPublicUrl(objectPath);
        } catch (_) {
          // Continue to other formats.
        }
      }
    }

    for (final bucket in _profilePhotoBuckets) {
      if (normalized.startsWith('$bucket/')) {
        final objectPath = normalized.substring(bucket.length + 1);
        try {
          return await _client.storage
              .from(bucket)
              .createSignedUrl(objectPath, 60 * 60 * 24 * 30);
        } catch (_) {
          return null;
        }
      }
    }

    for (final bucket in _profilePhotoBuckets) {
      try {
        return await _client.storage
            .from(bucket)
            .createSignedUrl(normalized, 60 * 60 * 24 * 30);
      } catch (_) {
        // Try next bucket.
      }
    }

    return null;
  }

  Future<void> _persistProfilePhotoPath(String path) async {
    final employee = await _currentEmployee();

    // Prefer updating the `employees` row (user requested canonical storage there).
    if (employee == null || employee['id'] == null) {
      throw ApiException(
        'Employee profile not found while saving profile photo path.',
      );
    }

    try {
      final numericEmployeeId = _toIntId(employee['id']);
      if (numericEmployeeId == null) {
        throw ApiException(
          'Employee profile not found while saving profile photo path.',
        );
      }

      await _client
          .from('employees')
          .update({'profilephoto_path': path})
          .eq('id', numericEmployeeId);
    } on PostgrestException catch (error) {
      throw ApiException(
        'Profile photo uploaded, but failed to save employees.profilephoto_path: ${error.message}',
      );
    } catch (error) {
      throw ApiException(
        'Profile photo uploaded, but failed to save employees.profilephoto_path: $error',
      );
    }
  }

  Future<void> _loadCurrentUserFromTable(String email) async {
    try {
      final rows = await _client
          .from('users')
          .select('*')
          .ilike('email', email)
          .limit(1);

      final list = _toMapList(rows);
      if (list.isNotEmpty) {
        _user = list.first;
        return;
      }
    } catch (_) {
      // Fallback to auth metadata when direct users-table read is unavailable.
    }

    final authUser = _client.auth.currentUser;
    _user = {
      'id': authUser?.id,
      'name':
          authUser?.userMetadata?['name']?.toString() ??
          authUser?.email ??
          'User',
      'email': authUser?.email ?? email,
    };
  }

  Future<void> _provisionAuthUserIfMissing({
    required String email,
    required String password,
    required dynamic employeeId,
  }) async {
    try {
      final authResult = await _client.auth.signUp(
        email: email,
        password: password,
      );

      final authUserId = authResult.user?.id ?? _client.auth.currentUser?.id;
      if (authUserId == null || authUserId.trim().isEmpty) {
        return;
      }

      await _syncEmployeeAuthId(
        employeeId: employeeId,
        authUserId: authUserId,
      );
    } catch (_) {
      // If the auth account already exists or signup is disabled, keep login working.
    }
  }

  Future<void> _syncEmployeeAuthId({
    required dynamic employeeId,
    required String authUserId,
  }) async {
    try {
      await _client
          .from('employees')
          .update({'auth_id': authUserId})
          .eq('id', employeeId);
    } catch (_) {
      // Keep login working even if auth_id sync fails.
    }
  }

  Future<Map<String, dynamic>?> _currentUserRow() async {
    if (_user != null) {
      return _user;
    }

    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      return null;
    }

    await _loadCurrentUserFromTable(email);
    return _user;
  }

  Future<Map<String, dynamic>?> _currentEmployee() async {
    final authUserId = _client.auth.currentUser?.id.trim() ?? '';
    final user = await _currentUserRow();
    final email = (user?['email'] ?? _client.auth.currentUser?.email ?? '')
        .toString()
        .trim();
    final userId = (user?['id'] ?? '').toString().trim();
    final userEmployeeId = (user?['employee_id'] ?? '').toString().trim();
    final userAuthId = (user?['auth_id'] ?? '').toString().trim();

    final employeeIdCandidates = <String>{
      if (userId.isNotEmpty) userId,
      if (authUserId.isNotEmpty) authUserId,
      if (userEmployeeId.isNotEmpty) userEmployeeId,
      if (userAuthId.isNotEmpty) userAuthId,
    }.toList();

    Future<List<Map<String, dynamic>>> fetchByAuthId() async {
      if (authUserId.isEmpty) {
        return const [];
      }
      try {
        final rows = await _client
            .from('employees')
            .select('*')
            .eq('auth_id', authUserId)
            .limit(1);
        return _toMapList(rows);
      } catch (_) {
        return const [];
      }
    }

    Future<List<Map<String, dynamic>>> fetchByEmail() async {
      if (email.isEmpty) {
        return const [];
      }
      try {
        final rows = await _client
            .from('employees')
            .select('*')
            .ilike('email', email)
            .limit(1);
        return _toMapList(rows);
      } catch (_) {
        return const [];
      }
    }

    Future<List<Map<String, dynamic>>> fetchByUserId() async {
      if (employeeIdCandidates.isEmpty) {
        return const [];
      }
      try {
        // `employees.user_id` is typically a numeric (bigint) column.
        // Filter the candidate list to numeric values only to avoid
        // Postgres errors like "invalid input syntax for type bigint"
        // when auth UIDs (UUID strings) are present.
        final numericCandidates = employeeIdCandidates
            .where((c) => int.tryParse(c.toString().trim()) != null)
            .map((c) => int.parse(c.toString().trim()))
            .toList();

        if (numericCandidates.isEmpty) {
          return const [];
        }

        final rows = await _client
            .from('employees')
            .select('*')
            .inFilter('user_id', numericCandidates)
            .limit(1);
        return _toMapList(rows);
      } catch (_) {
        return const [];
      }
    }

    var list = await fetchByAuthId();
    if (list.isEmpty) {
      list = await fetchByEmail();
    }
    if (list.isEmpty) {
      list = await fetchByUserId();
    }
    if (list.isEmpty) {
      return null;
    }

    final employee = list.first;
    if (employee['department_id'] != null) {
      final deptRows = await _client
          .from('departments')
          .select('id,name')
          .eq('id', employee['department_id'])
          .limit(1);
      final departments = _toMapList(deptRows);
      if (departments.isNotEmpty) {
        employee['department'] = departments.first;
      }
    }

    // If we've resolved an employee row, prefer using the employee's name
    // as the display name for the current user when the user record lacks
    // a friendly `name` (for example when reading from auth metadata).
    if (_user != null) {
      final currentUserName = (_user?['name'] ?? '').toString();
      final userEmail = (_user?['email'] ?? '').toString();
      if (currentUserName.isEmpty || currentUserName == userEmail) {
        final empName = (employee['name'] ?? employee['full_name'] ?? '')
            .toString()
            .trim();
        if (empName.isNotEmpty) {
          _user!['name'] = empName;
        }
      }
    }

    return employee;
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  int? _parseUserType(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  int? _toIntId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  List<dynamic> _employeeCredentialIdentifiers(Map<String, dynamic> employee) {
    final identifiers = <dynamic>[];
    final seen = <String>{};

    void addIdentifier(dynamic value) {
      if (value == null) {
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty || !seen.add(text)) {
        return;
      }
      identifiers.add(value);
    }

    // employee_credentials.employee_id has a FK to employees.id,
    // so reads should primarily use the same key used by inserts.
    addIdentifier(employee['id']);
    if (identifiers.isEmpty) {
      addIdentifier(employee['employee_id']);
    }
    return identifiers;
  }

  Future<dynamic> _queryEmployeeCredentials({
    required String select,
    required List<dynamic> employeeIdentifiers,
    bool orderByCreatedAtDesc = false,
  }) async {
    if (employeeIdentifiers.isEmpty) {
      return const [];
    }

    // Ensure we only pass numeric identifiers to employee_id (bigint).
    final numericIdentifiers = employeeIdentifiers
        .where((c) => int.tryParse(c.toString().trim()) != null)
        .map((c) => int.parse(c.toString().trim()))
        .toList();

    if (numericIdentifiers.isEmpty) {
      return const [];
    }

    dynamic query = _client.from('employee_credentials').select(select);

    if (numericIdentifiers.length == 1) {
      query = query.eq('employee_id', numericIdentifiers.first);
    } else {
      query = query.inFilter('employee_id', numericIdentifiers);
    }

    if (orderByCreatedAtDesc) {
      query = query.order('created_at', ascending: false);
    }

    return query;
  }

}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
