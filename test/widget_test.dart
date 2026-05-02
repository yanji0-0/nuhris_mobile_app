import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import 'package:nuhris_mobile_app/app_shell.dart';
import 'package:nuhris_mobile_app/providers/api_client_provider.dart';
import 'package:nuhris_mobile_app/services/api_client_contract.dart';
import 'package:nuhris_mobile_app/screens/auth/sign_in_screen.dart';

class FakeApiClient implements AppApiClient {
  @override
  Future<void> clearAllNotifications() async {}

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<bool> hasEmployeeAccess() async => false;

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<void> markNotificationRead(String notificationId) async {}

  @override
  Future<Map<String, dynamic>> getAccount() async => {};

  @override
  Future<Map<String, dynamic>> getDashboard() async => {};

  @override
  Future<String?> getProfilePhotoUrl() async => null;

  @override
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String filePath,
  }) async => {'url': ''};

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> updateAccount(Map<String, dynamic> updates) async {}

  @override
  Future<List<Map<String, dynamic>>> getAttendanceDtr() async => [];

  @override
  Future<Map<String, dynamic>> submitEmployeeSchedule({
    required String termLabel,
    required List<Map<String, dynamic>> days,
  }) async => {};

  @override
  Future<Map<String, dynamic>> getLeaveMonitoring() async => {};

  @override
  Future<Map<String, dynamic>> submitWfhMonitoring({
    required dynamic employeeId,
    required String wfhDate,
    String? timeIn,
    String? timeOut,
    required String filePath,
  }) async => {};

  @override
  Future<List<Map<String, dynamic>>> getWfhMonitoringSubmissions() async => [];

  @override
  Future<List<Map<String, dynamic>>> getEmployeeCredentials() async => [];

  @override
  Future<String?> getCredentialFileUrl(String storedPath) async => null;

  @override
  Future<String> uploadEmployeeCredentialFile({
    required dynamic employeeId,
    dynamic employeeAlternateId,
    required Uint8List fileBytes,
    required String originalFileName,
  }) async => '';

  @override
  Future<Map<String, dynamic>> createEmployeeCredential(
    Map<String, dynamic> payload,
  ) async => {};

  @override
  Future<void> deleteEmployeeCredential({
    required dynamic id,
    String? filePath,
  }) async {}
}

void main() {
  testWidgets('App loads sign in screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(FakeApiClient())],
        child: const AppShell(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Sign in to your account to continue'), findsOneWidget);
  });
}
