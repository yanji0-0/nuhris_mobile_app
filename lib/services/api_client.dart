import 'package:bcrypt/bcrypt.dart';
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
        .select('id')
        .eq('employee_id', employeeId);

    final leaveRequests = await _client
        .from('leave_requests')
        .select('id,status')
        .eq('employee_id', employeeId);

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

    return {
      'employee': employee,
      'attendance_summary': attendanceSummary,
      'leave_summary': {
        'balance_count': leaveBalances.length,
        'request_count': leaveRequests.length,
        'pending_requests': pending,
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
