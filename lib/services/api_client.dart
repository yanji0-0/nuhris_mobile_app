import 'package:bcrypt/bcrypt.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
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
    } catch (_) {
      // Fallback to public users table login for projects not using Supabase Auth.
      final rows = await _client
          .from('users')
          .select(
            'id,name,email,password,user_type,must_change_password,email_verified_at',
          )
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
  }

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

  Future<Map<String, dynamic>> getDashboard() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final employeeId = employee['id'];
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
      select: 'id,status,expires_at',
      employeeIdentifiers: credentialIdentifiers,
    );

    final user = await _currentUserRow();
    final userId = user?['id'];
    final notificationRows = userId == null
        ? const []
        : await _client
              .from('announcement_notifications')
              .select('id,is_read')
              .eq('user_id', userId);

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

    final activeCredentials = credentialRows.whereType<Map>().where((row) {
      final status = (row['status'] ?? '').toString().trim().toLowerCase();
      if (status.isEmpty) {
        return true;
      }
      return !nonCompliantStatuses.contains(status);
    }).length;

    final nonCompliantCredentials = credentialRows.whereType<Map>().where((
      row,
    ) {
      final status = (row['status'] ?? '').toString().trim().toLowerCase();
      return nonCompliantStatuses.contains(status);
    }).length;

    final now = DateTime.now();
    final expiringSoon = credentialRows.whereType<Map>().where((row) {
      final raw = (row['expires_at'] ?? '').toString();
      if (raw.isEmpty) {
        return false;
      }
      final date = DateTime.tryParse(raw);
      if (date == null || date.isBefore(now)) {
        return false;
      }
      final days = date.difference(now).inDays;
      return days <= 30;
    }).length;

    final unreadNotifications = notificationRows
        .whereType<Map>()
        .where((row) => row['is_read'] != true)
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
        'expiring_soon_count': expiringSoon,
        'non_compliant_count': nonCompliantCredentials,
        'compliant_count': activeCredentials,
      },
      'notifications_summary': {
        'total_count': notificationRows.length,
        'unread_count': unreadNotifications,
      },
    };
  }

  Future<List<Map<String, dynamic>>> getAttendanceDtr() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final rows = await _client
        .from('attendance_records')
        .select(
          'id,record_date,time_in,time_out,scheduled_time_in,scheduled_time_out,tardiness_minutes,undertime_minutes,overtime_minutes,status',
        )
        .eq('employee_id', employee['id'])
        .order('record_date', ascending: false);

    return _toMapList(rows);
  }

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

    final employeeId = employee['id'];
    final submittedBy = user['id'];
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

  Future<Map<String, dynamic>> getLeaveMonitoring() async {
    final employee = await _currentEmployee();
    if (employee == null) {
      throw ApiException('Employee profile not found.');
    }

    final employeeId = employee['id'];
    final balances = await _client
        .from('leave_balances')
        .select(
          'id,employee_id,leave_type,remaining_days,created_at,updated_at',
        )
        .eq('employee_id', employeeId);

    final requests = await _client
        .from('leave_requests')
        .select(
          'id,employee_id,leave_type,start_date,end_date,days_deducted,status,cutoff_date,reason,created_at,updated_at',
        )
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    return {'balances': _toMapList(balances), 'requests': _toMapList(requests)};
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

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    final rows = await _client
        .from('announcement_notifications')
        .select(
          'id,user_id,announcement_id,is_read,read_at,created_at,announcement:announcements(*)',
        )
        .eq('user_id', user['id'])
        .order('created_at', ascending: false);

    return _toMapList(rows);
  }

  Future<void> markAllNotificationsRead() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    try {
      await _client
          .from('announcement_notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', user['id']);
    } catch (error) {
      throw ApiException('Failed to mark notifications read: $error');
    }
  }

  Future<void> clearAllNotifications() async {
    final user = await _currentUserRow();
    if (user == null || user['id'] == null) {
      throw ApiException('User profile not found.');
    }

    try {
      await _client
          .from('announcement_notifications')
          .delete()
          .eq('user_id', user['id']);
    } catch (error) {
      throw ApiException('Failed to clear notifications: $error');
    }
  }

  Future<Map<String, dynamic>> getAccount() async {
    final user = await _currentUserRow();
    final employee = await _currentEmployee();

    return {'user': user, 'employee': employee};
  }

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
        await _client.from('users').update(update).eq('id', userId);
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
        await _client
            .from('employees')
            .update(employeeUpdate)
            .eq('id', employee['id']);
      }
    }

    final refreshed = await getAccount();
    return {'message': 'Account updated successfully.', ...refreshed};
  }

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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = currentPassword.trim();
    final next = newPassword.trim();

    if (current.isEmpty || next.isEmpty) {
      throw ApiException('Current and new passwords are required.');
    }

    if (next.length < 6) {
      throw ApiException('New password must be at least 6 characters long.');
    }

    final user = await _currentUserRow();
    final email = (user?['email'] ?? _client.auth.currentUser?.email ?? '')
        .toString()
        .trim();
    if (email.isEmpty) {
      throw ApiException(
        'Unable to resolve account email for password change.',
      );
    }

    if (_client.auth.currentSession != null) {
      try {
        await _client.auth.signInWithPassword(email: email, password: current);
      } catch (_) {
        throw ApiException('Current password is incorrect.');
      }

      try {
        await _client.auth.updateUser(UserAttributes(password: next));
      } on AuthException catch (error) {
        throw ApiException('Password update failed: ${error.message}');
      }

      // Keep legacy/fallback users-table login in sync with Supabase Auth.
      final hashedPassword = BCrypt.hashpw(next, BCrypt.gensalt());
      await _syncUsersPasswordHash(
        email: email,
        hashedPassword: hashedPassword,
        fallbackUserId: user?['id'],
      );
      return;
    }

    if (!_fallbackAuthenticated) {
      throw ApiException('You are not signed in. Please sign in again.');
    }

    final rows = await _client
        .from('users')
        .select('id,password,must_change_password')
        .ilike('email', email)
        .limit(1);

    if (rows.isEmpty) {
      throw ApiException('Account record not found for password change.');
    }

    final row = (rows.first as Map).cast<String, dynamic>();
    final storedPassword = (row['password'] ?? '').toString();
    final isBcrypt = storedPassword.startsWith(r'$2');
    final isValid = isBcrypt
        ? BCrypt.checkpw(current, storedPassword)
        : current == storedPassword;

    if (!isValid) {
      throw ApiException('Current password is incorrect.');
    }

    final hashedPassword = BCrypt.hashpw(next, BCrypt.gensalt());
    await _client
        .from('users')
        .update({'password': hashedPassword, 'must_change_password': false})
        .eq('id', row['id']);

    await _loadCurrentUserFromTable(email);
  }

  Future<void> _syncUsersPasswordHash({
    required String email,
    required String hashedPassword,
    dynamic fallbackUserId,
  }) async {
    final payload = {'password': hashedPassword, 'must_change_password': false};

    try {
      final byEmail = await _client
          .from('users')
          .update(payload)
          .ilike('email', email)
          .select('id');
      if (_toMapList(byEmail).isNotEmpty) {
        await _loadCurrentUserFromTable(email);
        return;
      }
    } catch (_) {
      // Fall back to ID update below.
    }

    if (fallbackUserId != null) {
      final byId = await _client
          .from('users')
          .update(payload)
          .eq('id', fallbackUserId)
          .select('id');
      if (_toMapList(byId).isNotEmpty) {
        await _loadCurrentUserFromTable(email);
        return;
      }
    }

    throw ApiException(
      'Password changed in Auth, but failed to sync users-table password record.',
    );
  }

  Future<List<Map<String, dynamic>>> getEmployeeCredentials() async {
    final employee = await _currentEmployee();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }

    final credentialIdentifiers = _employeeCredentialIdentifiers(employee);
    final rows = await _queryEmployeeCredentials(
      select:
          'id,employee_id,credential_type,title,department_id,expires_at,description,file_path,status,created_at,updated_at',
      employeeIdentifiers: credentialIdentifiers,
      orderByCreatedAtDesc: true,
    );

    return _toMapList(rows);
  }

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
      if (_credentialFilesBuckets.contains(possibleBucket)) {
        try {
          return _client.storage.from(possibleBucket).getPublicUrl(object);
        } catch (_) {
          try {
            return await _client.storage.from(possibleBucket).createSignedUrl(object, 60 * 60 * 24 * 30);
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
      try {
        // Try public URL first (faster)
        return _client.storage.from(bucket).getPublicUrl(normalized);
      } catch (_) {
        // Try next bucket
      }
    }

    // Last resort: try signed URLs in case RLS blocks public access
    for (final bucket in _credentialFilesBuckets) {
      try {
        return await _client.storage.from(bucket).createSignedUrl(normalized, 60 * 60 * 24 * 30);
      } catch (_) {
        // Try next bucket
      }
    }

    return null;
  }

  Future<List<String>> _listAvailableBuckets() async {
    try {
      final buckets = await _client.storage.listBuckets();
      return buckets.map((b) => b.name).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> deleteEmployeeCredential({required dynamic id, String? filePath}) async {
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

    final contentType = _contentTypeFromFileName(safeName);

    StorageException? lastMissingBucketError;
    StorageException? lastPolicyDeniedError;

    for (final bucket in _credentialFilesBuckets) {
      for (final prefix in candidatePrefixes) {
        final filePath = '$prefix/${timestamp}_$safeName';
        try {
          await _client.storage
              .from(bucket)
              .uploadBinary(
                filePath,
                fileBytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: false,
                ),
              );
          return '$bucket/$filePath';
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

  Future<Map<String, dynamic>> submitWfhMonitoring({
    required dynamic employeeId,
    required String wfhDate,
    String? timeIn,
    String? timeOut,
    required String filePath,
  }) async {
    final payload = <String, dynamic>{
      'employee_id': employeeId,
      'wfh_date': wfhDate,
      'time_in': timeIn,
      'time_out': timeOut,
      'file_path': filePath,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    // Try common table names used for WFH submissions. Try each until one succeeds.
    const candidateTables = [
      'wfh_monitoring_submissions',
      'wfh_monitorings',
      'wfh_submissions',
      'wfh_monitoring',
    ];

    for (final table in candidateTables) {
      try {
        final rows = await _client.from(table).insert(payload).select('id').limit(1);
        final list = _toMapList(rows);
        final insertedId = list.isNotEmpty ? list.first['id'] : null;
        return {'table': table, 'id': insertedId, 'message': 'Submission saved.'};
      } catch (_) {
        // Try next candidate.
      }
    }

    throw ApiException('Failed to save WFH monitoring submission: no matching table or permission denied.');
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
      await _client
          .from('employees')
          .update({'profilephoto_path': path})
          .eq('id', employee['id']);
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
    final user = await _currentUserRow();
    final email = (user?['email'] ?? _client.auth.currentUser?.email ?? '')
        .toString()
        .trim();
    final userId = (user?['id'] ?? '').toString().trim();

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
      if (userId.isEmpty) {
        return const [];
      }
      try {
        final rows = await _client
            .from('employees')
            .select('*')
            .eq('user_id', userId)
            .limit(1);
        return _toMapList(rows);
      } catch (_) {
        return const [];
      }
    }

    var list = await fetchByEmail();
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

    dynamic query = _client.from('employee_credentials').select(select);

    if (employeeIdentifiers.length == 1) {
      query = query.eq('employee_id', employeeIdentifiers.first);
    } else {
      query = query.inFilter('employee_id', employeeIdentifiers);
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
