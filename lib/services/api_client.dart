import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/academic_calendar_entry.dart';
import '../utils/app_log.dart';
import '../utils/upload_validation.dart';
import 'api_client_contract.dart';

class ApiClient implements AppApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _client.auth.currentSession != null;
  Map<String, dynamic>? get currentUser => _user;

  static const int _employeeUserType = 3;
  static const String _loginFailedMessage =
      'These credentials do not match our records.';

  /// Private bucket shared with the web portal (credentials, degrees, WFH).
  static const String _filesBucket = 'credentials';

  /// Lifetime of signed URLs for documents and profile photos.
  static const int _documentUrlSeconds = 300;
  static const int _photoUrlSeconds = 60 * 60;

  /// Only the columns the app displays (no password/remember_token, and no
  /// phone/address, which the employee app never shows).
  static const String _userColumns = 'id,name,email,user_type';
  static const String _employeeColumns =
      'id,employee_id,first_name,last_name,email,department_id,position,'
      'employment_type,ranking,status,hire_date,official_time_in,'
      'official_time_out,auth_id,profilephoto_path';

  /// Runs a backend operation and converts any unexpected error into a
  /// user-safe [ApiException]. Technical details (Postgrest/RLS/storage
  /// messages, object keys) are only logged in debug builds.
  Future<T> _guard<T>(
    String operation,
    String userMessage,
    Future<T> Function() body,
  ) async {
    try {
      return await body();
    } on ApiException {
      rethrow;
    } on PostgrestException catch (error) {
      appLog('$operation failed (code ${error.code})', error.message);
      throw ApiException(userMessage);
    } on StorageException catch (error) {
      appLog('$operation failed (status ${error.statusCode})', error.message);
      throw ApiException(userMessage);
    } catch (error) {
      appLog('$operation failed', error);
      throw ApiException(userMessage);
    }
  }

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
    } catch (error) {
      // Fall through and force logout for unresolved or invalid user records.
      appLog('Employee access check failed', error.runtimeType);
    }

    await logout();
    return false;
  }

  /// Supabase Auth is the only authentication mechanism. Passwords are never
  /// read, compared or stored on the device; accounts are provisioned by the
  /// web portal (Supabase Auth Admin API), never from the app.
  @override
  Future<void> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ApiException('Email and password are required.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthRetryableFetchException catch (error) {
      appLog('Sign-in network error', error.statusCode);
      throw ApiException(
        'Unable to reach the server. Check your connection and try again.',
      );
    } on AuthException catch (error) {
      appLog('Sign-in rejected (${error.code ?? error.statusCode})');
      switch (error.code) {
        case 'email_not_confirmed':
          throw ApiException('Please verify your email before signing in.');
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          throw ApiException(
            'Too many sign-in attempts. Please wait a moment and try again.',
          );
        default:
          throw ApiException(_loginFailedMessage);
      }
    } catch (error) {
      appLog('Sign-in failed', error.runtimeType);
      throw ApiException('Unable to sign in right now. Please try again.');
    }

    _user = null;
    final allowed = await _guard(
      'Load signed-in profile',
      'Unable to load your employee profile. Please try again.',
      () async {
        await _loadCurrentUserFromTable(normalizedEmail);
        final userType = _parseUserType(_user?['user_type']);
        if (userType != null && userType != _employeeUserType) {
          return false;
        }
        return await _currentEmployee() != null;
      },
    );

    if (!allowed) {
      await logout();
      throw ApiException(_loginFailedMessage);
    }
  }

  /// Confirms the signed-in employee's password with Supabase Auth before a
  /// sensitive operation (step-up authentication). Nothing is stored.
  @override
  Future<bool> reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty || password.isEmpty) return false;
    try {
      final result = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return result.session != null;
    } on AuthRetryableFetchException {
      throw ApiException(
        'Unable to reach the server. Check your connection and try again.',
      );
    } on AuthException catch (error) {
      appLog('Re-authentication rejected (${error.code ?? error.statusCode})');
      return false;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      // Ignore logout errors; the local session is cleared below.
      appLog('Sign-out request failed', error.runtimeType);
    } finally {
      _user = null;
    }
  }

  /// Mirrors the web `Employee\PortalController::dashboard` data: present
  /// days per cutoff of the current month and the latest approved schedule.
  /// Recent alerts and the academic calendar come from their own providers.
  @override
  Future<Map<String, dynamic>> getDashboard() => _guard(
        'Load dashboard',
        'Unable to load your dashboard. Please try again.',
        () async {
          final user = await _currentUserRow();
          final employeeId = await _requireEmployeeId();

          // The web app runs on Asia/Manila (UTC+8, no DST), so the cutoffs
          // are resolved against Manila's calendar date, not the device clock.
          final manilaNow =
              DateTime.now().toUtc().add(const Duration(hours: 8));
          final year = manilaNow.year;
          final month = manilaNow.month;
          final lastDay = DateTime(year, month + 1, 0).day;

          String isoDate(int day) =>
              '${year.toString().padLeft(4, '0')}-'
              '${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}';

          Future<int> countPresentDays(int fromDay, int toDay) async {
            final rows = await _client
                .from('attendance_records')
                .select('id')
                .eq('employee_id', employeeId)
                .eq('status', 'present')
                .gte('record_date', isoDate(fromDay))
                .lte('record_date', isoDate(toDay));
            return rows.length;
          }

          final presentDays = await Future.wait([
            countPresentDays(1, 15),
            countPresentDays(16, lastDay),
          ]);

          // Same ordering as Eloquent's latest('reviewed_at')->latest(
          // 'updated_at') on Postgres, where DESC places NULLs first.
          final scheduleRows = await _client
              .from('employee_schedule_submissions')
              .select(
                'id,term_label,semester_label,status,reviewed_at,updated_at',
              )
              .eq('employee_id', employeeId)
              .eq('status', 'approved')
              .order('reviewed_at', ascending: false, nullsFirst: true)
              .order('updated_at', ascending: false, nullsFirst: true)
              .limit(1);
          final scheduleList = _toMapList(scheduleRows);

          return {
            'user': user,
            'employee': await _currentEmployee(),
            'present_days': {
              'first_cutoff': presentDays[0],
              'second_cutoff': presentDays[1],
            },
            'latest_approved_schedule':
                scheduleList.isEmpty ? null : scheduleList.first,
          };
        },
      );

  @override
  Future<List<Map<String, dynamic>>> getAttendanceDtr() => _guard(
        'Load attendance',
        'Unable to load your attendance records. Please try again.',
        () async {
          final employeeId = await _requireEmployeeId();
          final rows = await _client
              .from('attendance_records')
              .select(
                'id,record_date,time_in,time_out,scheduled_time_in,scheduled_time_out,tardiness_minutes,undertime_minutes,overtime_minutes,status,schedule_status,schedule_notes',
              )
              .eq('employee_id', employeeId)
              .order('record_date', ascending: false);
          return _toMapList(rows);
        },
      );

  @override
  Future<Map<String, dynamic>?> getCurrentEmployeeScheduleSubmission() =>
      _guard(
        'Load schedule submission',
        'Unable to load your schedule. Please try again.',
        () async {
          final employeeId = await _requireEmployeeId();
          final submissionRows = await _client
              .from('employee_schedule_submissions')
              .select(
                'id,employee_id,term_label,semester_label,status,submitted_at,reviewed_at,review_notes,is_current',
              )
              .eq('employee_id', employeeId)
              .order('submitted_at', ascending: false)
              .limit(1);

          final submissionList = _toMapList(submissionRows);
          if (submissionList.isEmpty) {
            return null;
          }

          final submission = submissionList.first;
          final dayRows = await _client
              .from('employee_schedule_days')
              .select('day_name,day_index,has_work,time_in,time_out')
              .eq('schedule_submission_id', submission['id'])
              .order('day_index', ascending: true);

          return {
            'submission': submission,
            'days': _toMapList(dayRows),
          };
        },
      );

  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$');

  @override
  Future<Map<String, dynamic>> submitEmployeeSchedule({
    required String termLabel,
    required List<Map<String, dynamic>> days,
  }) async {
    final normalizedTerm = termLabel.trim();
    if (normalizedTerm.isEmpty || normalizedTerm.length > 100) {
      throw ApiException('Please choose a valid term.');
    }

    // Normalize term labels to canonical "Term" form so web and mobile match.
    // e.g. convert "3rd Semester" -> "3rd Term"
    final canonicalTerm = normalizedTerm.replaceAll(
      RegExp(r'Semester', caseSensitive: false),
      'Term',
    );

    if (days.isEmpty || days.length > 7) {
      throw ApiException('At least one schedule day is required.');
    }

    final dayRows = <Map<String, dynamic>>[];
    for (final day in days) {
      final hasWork = day['has_work'] == true;
      final dayIndex = day['day_index'];
      final dayName = (day['day_name'] ?? '').toString().trim();
      if (dayIndex is! int || dayIndex < 0 || dayIndex > 6 || dayName.isEmpty) {
        throw ApiException('The schedule contains an invalid day.');
      }
      final timeIn = day['time_in']?.toString();
      final timeOut = day['time_out']?.toString();
      if (hasWork) {
        if (timeIn == null ||
            timeOut == null ||
            !_timePattern.hasMatch(timeIn) ||
            !_timePattern.hasMatch(timeOut)) {
          throw ApiException('Set a valid Time In and Time Out for $dayName.');
        }
      }
      dayRows.add({
        'day_name': dayName,
        'day_index': dayIndex,
        'has_work': hasWork,
        'time_in': hasWork ? timeIn : null,
        'time_out': hasWork ? timeOut : null,
      });
    }

    return _guard(
      'Submit schedule',
      'Unable to submit your schedule. Please try again.',
      () async {
        final user = await _currentUserRow();
        final employeeId = await _requireEmployeeId();
        final submittedBy = _toIntId(user?['id']);
        if (submittedBy == null) {
          throw ApiException('User profile not found.');
        }

        final submissionRows = await _client
            .from('employee_schedule_submissions')
            .insert({
              'employee_id': employeeId,
              'submitted_by': submittedBy,
              'semester_label': canonicalTerm,
              'term_label': canonicalTerm,
              'status': 'pending',
              'submitted_at': DateTime.now().toUtc().toIso8601String(),
              'is_current': false,
            })
            .select('id');

        final submissionId = _toIntId(_toMapList(submissionRows).firstOrNull?['id']);
        if (submissionId == null) {
          throw ApiException('Unable to submit your schedule. Please try again.');
        }

        await _client.from('employee_schedule_days').insert([
          for (final row in dayRows)
            {'schedule_submission_id': submissionId, ...row},
        ]);

        return {
          'message': 'Schedule submitted successfully.',
          'submission_id': submissionId,
          'term_label': normalizedTerm,
          'day_count': dayRows.length,
        };
      },
    );
  }

  @override
  Future<Map<String, dynamic>> getLeaveMonitoring() => _guard(
        'Load leave monitoring',
        'Unable to load your leave records. Please try again.',
        () async {
          final employee = await _currentEmployee();
          final employeeId = _toIntId(employee?['id']);
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
                    (left['updated_at'] ?? left['created_at'] ?? '')
                        .toString(),
                  ) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final rightUpdated = DateTime.tryParse(
                    (right['updated_at'] ?? right['created_at'] ?? '')
                        .toString(),
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
              // Web: `latest('start_date')` (Postgres DESC puts NULLs first).
              .order('start_date', ascending: false, nullsFirst: true);

          return {
            'balances': sortedBalances,
            'requests': _toMapList(requests),
            // Needed for the web's current-employment-year usage window.
            'hire_date': employee?['hire_date'],
          };
        },
      );

  @override
  Future<List<AcademicCalendarEntry>> getAcademicCalendarEntries() async {
    final baseUrl = AppConfig.secureBaseUrl;
    if (baseUrl == null) {
      appLog('Academic Calendar API URL is missing or not HTTPS');
      throw ApiException('The Academic Calendar is not available right now.');
    }

    final uri = Uri.parse('$baseUrl/api/academic-calendar');

    late http.Response response;
    try {
      response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      appLog('Academic Calendar request failed', error.runtimeType);
      throw ApiException(
        'Unable to reach the Academic Calendar. Please try again later.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      appLog('Academic Calendar HTTP ${response.statusCode}');
      throw ApiException(
        'Unable to load the Academic Calendar. Please try again later.',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('The Academic Calendar returned invalid data.');
    }
    if (decoded is! List) {
      throw ApiException('The Academic Calendar returned invalid data.');
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
  Future<List<Map<String, dynamic>>> getNotifications() => _guard(
        'Load notifications',
        'Unable to load notifications. Please try again.',
        () async {
          final user = await _currentUserRow();
          final userId = _toIntId(user?['id']);
          if (userId == null) {
            throw ApiException('User profile not found.');
          }

          // STEP 1: Load the employee's notification rows.
          final notifications = _toMapList(
            await _client
                .from('announcement_notifications')
                .select(
                  'id,user_id,announcement_id,is_read,read_at,created_at,updated_at,redirect_url',
                )
                .eq('user_id', userId)
                .order('created_at', ascending: false),
          );
          if (notifications.isEmpty) {
            return const <Map<String, dynamic>>[];
          }

          // STEP 2: Load the referenced announcements in one query.
          final announcementIds = <int>{
            for (final n in notifications)
              ?_toIntId(n['announcement_id']),
          };
          final announcementMap = <int, Map<String, dynamic>>{};
          if (announcementIds.isNotEmpty) {
            final rows = _toMapList(
              await _client
                  .from('announcements')
                  .select(
                    'id,title,content,priority,target_office,published_at,created_at,is_published,deleted_at,expires_at',
                  )
                  .inFilter('id', announcementIds.toList()),
            );
            for (final row in rows) {
              final id = _toIntId(row['id']);
              if (id != null) announcementMap[id] = row;
            }
          }

          // STEP 3: Attach announcements. announcement_notifications is the
          // source of truth that the user received a notification, even if
          // the announcement metadata is unreadable.
          return [
            for (final notification in notifications)
              {
                ...notification,
                'announcement': announcementMap[
                        _toIntId(notification['announcement_id'])] ??
                    <String, dynamic>{
                      'title': 'Announcement',
                      'content': '',
                      'priority': 'medium',
                    },
              },
          ];
        },
      );

  @override
  Future<void> markAllNotificationsRead() => _guard(
        'Mark notifications read',
        'Unable to update notifications. Please try again.',
        () async {
          final userId = _toIntId((await _currentUserRow())?['id']);
          if (userId == null) return;
          await _client
              .from('announcement_notifications')
              .update({
                'is_read': true,
                'read_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
        },
      );

  @override
  Future<void> markNotificationRead(String notificationId) => _guard(
        'Mark notification read',
        'Unable to update this notification. Please try again.',
        () async {
          final userId = _toIntId((await _currentUserRow())?['id']);
          final id = _toIntId(notificationId);
          if (userId == null || id == null) return;
          await _client
              .from('announcement_notifications')
              .update({
                'is_read': true,
                'read_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .eq('user_id', userId);
        },
      );

  @override
  Future<void> clearAllNotifications() => _guard(
        'Clear notifications',
        'Unable to clear notifications. Please try again.',
        () async {
          final userId = _toIntId((await _currentUserRow())?['id']);
          if (userId == null) return;
          await _client
              .from('announcement_notifications')
              .delete()
              .eq('user_id', userId);
        },
      );

  @override
  Future<Map<String, dynamic>> getAccount() => _guard(
        'Load account',
        'Unable to load your account. Please try again.',
        () async {
          final user = await _currentUserRow();
          final employee = await _currentEmployee();
          return {'user': user, 'employee': employee};
        },
      );

  /// Short-lived signed URL for the employee's profile photo, if any.
  @override
  Future<String?> getProfilePhotoUrl() async {
    try {
      final employee = await _currentEmployee();
      final stored =
          (employee?['profilephoto_path'] ?? '').toString().trim();
      if (stored.isNotEmpty) {
        final url = await _signStoredPhotoPath(stored);
        if (url != null) return url;
      }

      // Location used by earlier app versions: <auth uid>/avatar.jpg.
      final authUid = (_client.auth.currentUser?.id ?? '').trim();
      if (authUid.isEmpty) return null;
      return await _client.storage
          .from(_filesBucket)
          .createSignedUrl('$authUid/avatar.jpg', _photoUrlSeconds);
    } catch (error) {
      appLog('Profile photo lookup failed', error.runtimeType);
      return null;
    }
  }

  Future<String?> _signStoredPhotoPath(String storedPath) async {
    // Legacy rows may store a full URL; only HTTPS URLs are accepted.
    final uri = Uri.tryParse(storedPath);
    if (uri != null && uri.hasScheme) {
      return AppConfig.isHttpsUrl(storedPath) ? storedPath : null;
    }

    var objectPath = storedPath;
    if (objectPath.startsWith('$_filesBucket/')) {
      objectPath = objectPath.substring(_filesBucket.length + 1);
    }
    try {
      return await _client.storage
          .from(_filesBucket)
          .createSignedUrl(objectPath, _photoUrlSeconds);
    } catch (error) {
      appLog('Profile photo signing failed', error.runtimeType);
      return null;
    }
  }

  /// Mirrors the web `PrivacyNoticeController::acknowledge`:
  /// `updateOrCreate` on (user_id, privacy_notice_version) in
  /// `privacy_notice_acknowledgments`, setting `acknowledged_at` to now.
  @override
  Future<void> acknowledgePrivacyNotice({required String version}) => _guard(
        'Record Privacy Notice acknowledgment',
        'Unable to save your acknowledgment. Please try again.',
        () async {
          final userId = _toIntId((await _currentUserRow())?['id']);
          if (userId == null) {
            throw ApiException('User profile not found.');
          }

          // Laravel stores these `timestamp without time zone` columns in
          // Asia/Manila wall-clock time (UTC+8).
          final manila = DateTime.now().toUtc().add(const Duration(hours: 8));
          String two(int value) => value.toString().padLeft(2, '0');
          final now =
              '${manila.year}-${two(manila.month)}-${two(manila.day)} '
              '${two(manila.hour)}:${two(manila.minute)}:${two(manila.second)}';

          final existing = _toMapList(
            await _client
                .from('privacy_notice_acknowledgments')
                .select('id')
                .eq('user_id', userId)
                .eq('privacy_notice_version', version)
                .limit(1),
          );

          if (existing.isNotEmpty) {
            await _client
                .from('privacy_notice_acknowledgments')
                .update({'acknowledged_at': now, 'updated_at': now})
                .eq('id', existing.first['id']);
          } else {
            await _client.from('privacy_notice_acknowledgments').insert({
              'user_id': userId,
              'privacy_notice_version': version,
              'acknowledged_at': now,
              'created_at': now,
              'updated_at': now,
            });
          }
        },
      );

  /// Read-only mirror of the web `Employee\PortalController::profile` degree
  /// list: the employee's `employee_credentials` rows of type `degrees`.
  /// Submitting or deleting degrees is only available on the web portal.
  @override
  Future<List<Map<String, dynamic>>> getEmployeeDegrees() => _guard(
        'Load degrees',
        'Unable to load your degrees. Please try again.',
        () async {
          final employeeId = await _requireEmployeeId();
          final rows = await _client
              .from('employee_credentials')
              .select(
                'id,employee_id,credential_type,degree_level,status,file_path,'
                'original_filename,review_notes,created_at',
              )
              .eq('employee_id', employeeId)
              .eq('credential_type', 'degrees')
              .order('id', ascending: true);
          return _toMapList(rows);
        },
      );

  /// Signs a stored object key in the private "credentials" bucket for
  /// [_documentUrlSeconds]. Web stores only the object key, e.g.
  /// `employee-12/1755712345_a3f19c2e.pdf`.
  @override
  Future<String?> getCredentialFileUrl(String storedPath) async {
    final normalized = storedPath.trim();
    if (normalized.isEmpty) return null;

    // Legacy rows may already store a full URL; never open plain HTTP.
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      if (AppConfig.isHttpsUrl(normalized)) return normalized;
      throw ApiException('This file cannot be opened securely.');
    }

    var objectKey = normalized;
    if (objectKey.startsWith('$_filesBucket/')) {
      objectKey = objectKey.substring(_filesBucket.length + 1);
    }

    return _guard(
      'Sign document URL',
      'Unable to open this file right now. Please try again.',
      () => _client.storage
          .from(_filesBucket)
          .createSignedUrl(objectKey, _documentUrlSeconds),
    );
  }

  /// Uploads a WFH file for the signed-in employee after validating size,
  /// extension and file signature. Returns the stored object key, in the same
  /// `employee-<id>/wfh-monitoring/<time>_<random>.<ext>` layout as the web.
  @override
  Future<String> uploadEmployeeCredentialFile({
    required Uint8List fileBytes,
    required String originalFileName,
  }) async {
    final validated = validateUpload(
      originalName: originalFileName,
      bytes: fileBytes,
    );

    return _guard(
      'Upload WFH file',
      'Unable to upload the file. Please try again.',
      () async {
        final employeeId = await _requireEmployeeId();
        final objectKey =
            'employee-$employeeId/wfh-monitoring/${validated.storedFileName}';
        await _client.storage.from(_filesBucket).uploadBinary(
              objectKey,
              fileBytes,
              fileOptions: FileOptions(
                contentType: validated.contentType,
                upsert: false,
              ),
            );
        return objectKey;
      },
    );
  }

  @override
  Future<Map<String, dynamic>> submitWfhMonitoring({
    required DateTime wfhDate,
    required String timeIn,
    required String timeOut,
    required String filePath,
    required String originalFilename,
  }) async {
    if (!_timePattern.hasMatch(timeIn) || !_timePattern.hasMatch(timeOut)) {
      throw ApiException('Please enter a valid time in and time out.');
    }
    if (timeOut.compareTo(timeIn) <= 0) {
      throw ApiException('The time out must be later than the time in.');
    }

    final date =
        '${wfhDate.year.toString().padLeft(4, '0')}-'
        '${wfhDate.month.toString().padLeft(2, '0')}-'
        '${wfhDate.day.toString().padLeft(2, '0')}';

    return _guard(
      'Submit WFH monitoring',
      'Unable to save your WFH submission. Please try again.',
      () async {
        final userId = _toIntId((await _currentUserRow())?['id']);
        if (userId == null) {
          throw ApiException('User profile not found.');
        }
        final employeeId = await _requireEmployeeId();

        // Same rule as the web: one pending/approved submission per date.
        final existing = await _client
            .from('wfh_monitoring_submissions')
            .select('id')
            .eq('employee_id', employeeId)
            .eq('wfh_date', date)
            .inFilter('status', ['pending', 'approved'])
            .limit(1);
        if (existing.isNotEmpty) {
          throw ApiException(
            'You already have a pending or approved WFH submission for that date.',
          );
        }

        final now = DateTime.now().toIso8601String();
        final rows = await _client
            .from('wfh_monitoring_submissions')
            .insert({
              'employee_id': employeeId,
              'submitted_by': userId,
              'wfh_date': date,
              'time_in': timeIn,
              'time_out': timeOut,
              'file_path': filePath,
              'original_filename': originalFilename,
              'status': 'pending',
              'submitted_at': now,
              'created_at': now,
              'updated_at': now,
            })
            .select('id')
            .limit(1);
        final list = _toMapList(rows);
        return {
          'id': list.isNotEmpty ? list.first['id'] : null,
          'message': 'Submission saved.',
        };
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getWfhMonitoringSubmissions() => _guard(
        'Load WFH submissions',
        'Unable to load your WFH submissions. Please try again.',
        () async {
          final employeeId = await _requireEmployeeId();
          final rows = await _client
              .from('wfh_monitoring_submissions')
              .select(
                'id,employee_id,wfh_date,time_in,time_out,monitoring_link,'
                'file_path,original_filename,status,submitted_at,reviewed_at,'
                'review_notes,created_at,updated_at',
              )
              .eq('employee_id', employeeId)
              .order('submitted_at', ascending: false);
          return _toMapList(rows);
        },
      );

  /// Minimum supported Android build, from the `mobile_app_versions` table.
  /// Returns null when no policy is configured or it cannot be read.
  @override
  Future<Map<String, dynamic>?> getMobileVersionPolicy() async {
    try {
      final rows = await _client
          .from('mobile_app_versions')
          .select('min_version_code,latest_version_name,update_url,message')
          .eq('platform', 'android')
          .limit(1);
      final list = _toMapList(rows);
      return list.isEmpty ? null : list.first;
    } catch (error) {
      appLog('Version policy unavailable', error.runtimeType);
      return null;
    }
  }

  Future<int> _requireEmployeeId() async {
    final employeeId = _toIntId((await _currentEmployee())?['id']);
    if (employeeId == null) {
      throw ApiException('Employee profile not found.');
    }
    return employeeId;
  }

  Future<void> _loadCurrentUserFromTable(String email) async {
    try {
      // `ilike` treats `_`/`%` as wildcards, so confirm the match in Dart.
      final rows = _toMapList(
        await _client
            .from('users')
            .select(_userColumns)
            .ilike('email', email)
            .limit(5),
      );
      final match = rows.where(
        (row) =>
            (row['email'] ?? '').toString().trim().toLowerCase() ==
            email.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _user = match.first;
        return;
      }
    } catch (error) {
      // Fallback to auth metadata when the users row is not readable.
      appLog('Users row lookup failed', error.runtimeType);
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

  Future<Map<String, dynamic>?> _currentUserRow() async {
    if (_user != null) {
      return _user;
    }

    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      return null;
    }

    await _loadCurrentUserFromTable(email.trim().toLowerCase());
    return _user;
  }

  /// Resolves the signed-in employee from the Supabase Auth identity: first
  /// by `employees.auth_id = auth.uid()`, then by the verified Auth email.
  Future<Map<String, dynamic>?> _currentEmployee() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    final authUserId = authUser.id.trim();
    final email = (authUser.email ?? '').trim();
    await _currentUserRow();

    Future<List<Map<String, dynamic>>> fetchByAuthId() async {
      if (authUserId.isEmpty) {
        return const [];
      }
      try {
        final rows = await _client
            .from('employees')
            .select(_employeeColumns)
            .eq('auth_id', authUserId)
            .isFilter('deleted_at', null)
            .limit(1);
        return _toMapList(rows);
      } catch (error) {
        appLog('Employee lookup by auth id failed', error.runtimeType);
        return const [];
      }
    }

    Future<List<Map<String, dynamic>>> fetchByEmail() async {
      if (email.isEmpty) {
        return const [];
      }
      try {
        // `ilike` treats `_`/`%` (and PostgREST `*`) as wildcards, so confirm
        // the match in Dart; an exact-case match wins, as on the web
        // (`Employee::where('email', ...)`, soft-deleted rows excluded).
        final rows = await _client
            .from('employees')
            .select(_employeeColumns)
            .ilike('email', email)
            .isFilter('deleted_at', null)
            .order('id', ascending: true);
        final matches = _toMapList(rows)
            .where(
              (row) =>
                  (row['email'] ?? '').toString().trim().toLowerCase() ==
                  email.toLowerCase(),
            )
            .toList();
        final exact = matches.where(
          (row) => (row['email'] ?? '').toString().trim() == email,
        );
        return exact.isNotEmpty ? [exact.first] : matches.take(1).toList();
      } catch (error) {
        appLog('Employee lookup by email failed', error.runtimeType);
        return const [];
      }
    }

    var list = await fetchByAuthId();
    if (list.isEmpty) {
      list = await fetchByEmail();
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
        final empName =
            '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'
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
}

/// Error whose [message] is always safe to show to the employee. Technical
/// details are logged (debug builds only) where the error is created.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// User-safe text for any error: [ApiException] / validation messages are
/// shown as-is; anything else becomes [fallback].
String userMessageFor(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) return error.message;
  if (error is UploadValidationException) return error.message;
  return fallback;
}
