import 'dart:typed_data';

import '../models/academic_calendar_entry.dart';

abstract class AppApiClient {
  Future<bool> hasEmployeeAccess();
  Future<void> login({required String email, required String password});
  Future<void> logout();

  // Notifications / dashboard / account
  Future<List<Map<String, dynamic>>> getNotifications();
  Future<Map<String, dynamic>> getDashboard();
  Future<Map<String, dynamic>> getAccount();

  // Profile photo
  Future<String?> getProfilePhotoUrl();
  Future<Map<String, dynamic>> uploadProfilePhoto({required String filePath});

  // Account management
  Future<void> updateAccount(Map<String, dynamic> updates);

  // Notifications helpers
  Future<void> markAllNotificationsRead();
  Future<void> markNotificationRead(String notificationId);
  Future<void> clearAllNotifications();

  // Academic Calendar
  Future<List<AcademicCalendarEntry>> getAcademicCalendarEntries();

  // Attendance / schedule
  Future<List<Map<String, dynamic>>> getAttendanceDtr();
  Future<Map<String, dynamic>?> getCurrentEmployeeScheduleSubmission();
  Future<Map<String, dynamic>> submitEmployeeSchedule({
    required String termLabel,
    required List<Map<String, dynamic>> days,
  });

  // Leave / WFH monitoring
  Future<Map<String, dynamic>> getLeaveMonitoring();
  Future<Map<String, dynamic>> submitWfhMonitoring({
    required dynamic employeeId,
    required String wfhDate,
    String? timeIn,
    String? timeOut,
    required String filePath,
  });
  Future<List<Map<String, dynamic>>> getWfhMonitoringSubmissions();

  // Privacy Notice (same acknowledgment record the web portal writes)
  Future<void> acknowledgePrivacyNotice({required String version});

  // Academic degrees (read-only; submissions happen on the web portal)
  Future<List<Map<String, dynamic>>> getEmployeeDegrees();

  // Files in the shared "credentials" storage bucket (used by WFH monitoring)
  Future<String?> getCredentialFileUrl(String storedPath);
  Future<String> uploadEmployeeCredentialFile({
    required dynamic employeeId,
    dynamic employeeAlternateId,
    required Uint8List fileBytes,
    required String originalFileName,
  });
}
