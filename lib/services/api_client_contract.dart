import 'dart:typed_data';

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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> updateAccount(Map<String, dynamic> updates);

  // Notifications helpers
  Future<void> markAllNotificationsRead();
  Future<void> markNotificationRead(String notificationId);
  Future<void> clearAllNotifications();

  // Attendance / schedule
  Future<List<Map<String, dynamic>>> getAttendanceDtr();
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

  // Employee credentials
  Future<List<Map<String, dynamic>>> getEmployeeCredentials();
  Future<String?> getCredentialFileUrl(String storedPath);
  Future<String> uploadEmployeeCredentialFile({
    required dynamic employeeId,
    dynamic employeeAlternateId,
    required Uint8List fileBytes,
    required String originalFileName,
  });
  Future<Map<String, dynamic>> createEmployeeCredential(
    Map<String, dynamic> payload,
  );
  Future<void> deleteEmployeeCredential({
    required dynamic id,
    String? filePath,
  });
}
