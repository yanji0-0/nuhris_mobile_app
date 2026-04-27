import 'package:bcrypt/bcrypt.dart';
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
  static const List<String> _credentialFilesBuckets = [
    'employee_credentials',
    'employee-credentials',
    'credentials',
    'uploads',
  ];

  Future<bool> hasEmployeeAccess() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      final user = await _currentUserRow();
      final userType = _parseUserType(user?['user_type']);
      if (userType != _employeeUserType) {
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
    if (currentUserType != _employeeUserType) {
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

    final credentialRows = await _client
        .from('employee_credentials')
        .select('id,status,expires_at')
        .eq('employee_id', employeeId);

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

    final activeStatuses = <String>{
      'active',
      'verified',
      'approved',
      'compliant',
      'valid',
    };

    final nonCompliantStatuses = <String>{
      'expired',
      'rejected',
      'invalid',
      'non-compliant',
      'non_compliant',
    };

    final activeCredentials = credentialRows.whereType<Map>().where((row) {
      final status = (row['status'] ?? '').toString().trim().toLowerCase();
      return activeStatuses.contains(status);
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

  Future<List<Map<String, dynamic>>> getEmployeeCredentials() async {
    final employee = await _currentEmployee();
    if (employee == null || employee['id'] == null) {
      throw ApiException('Employee profile not found.');
    }

    final rows = await _client
        .from('employee_credentials')
        .select(
          'id,employee_id,credential_type,title,department_id,expires_at,description,file_path,status,created_at,updated_at',
        )
        .eq('employee_id', employee['id'])
        .order('created_at', ascending: false);

    return _toMapList(rows);
  }

  Future<Map<String, dynamic>> createEmployeeCredential(
    Map<String, dynamic> payload,
  ) async {
    final rows = await _client
        .from('employee_credentials')
        .insert(payload)
        .select();

    final list = _toMapList(rows);
    return list.isNotEmpty ? list.first : <String, dynamic>{};
  }

  Future<String> uploadEmployeeCredentialFile({
    required dynamic employeeId,
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
      if (authUid.isNotEmpty) authUid,
      if (userId.isNotEmpty) 'user-$userId',
      if (userId.isNotEmpty) userId,
    }.toList();

    final contentType = _contentTypeFromFileName(safeName);

    StorageException? lastMissingBucketError;
    StorageException? lastPolicyDeniedError;

    for (final bucket in _credentialFilesBuckets) {
      for (final prefix in candidatePrefixes) {
        final filePath = '$prefix/$timestamp\_$safeName';
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

  Future<void> _loadCurrentUserFromTable(String email) async {
    final rows = await _client
        .from('users')
        .select(
          'id,name,email,user_type,must_change_password,email_verified_at',
        )
        .ilike('email', email)
        .limit(1);

    final list = _toMapList(rows);
    if (list.isNotEmpty) {
      _user = list.first;
      return;
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
        .toString();
    if (email.isEmpty) {
      return null;
    }

    final rows = await _client
        .from('employees')
        .select(
          'id,employee_id,first_name,last_name,email,phone,department_id,position,employment_type,ranking,status,hire_date,official_time_in,official_time_out,resume_last_updated_at,address',
        )
        .ilike('email', email)
        .limit(1);

    final list = _toMapList(rows);
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
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
