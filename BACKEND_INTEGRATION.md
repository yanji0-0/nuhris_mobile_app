# Backend Integration Guide

NUHRIS uses a Supabase-backed backend layer for authentication and app data.
The Flutter UI should talk to Riverpod providers first, then let the providers call the shared API client.
That keeps the screens focused on presentation and makes the backend flow easier to test and extend.

## How the Layers Fit Together

```text
1. main.dart initializes Supabase and wraps the app in ProviderScope
    ↓
2. app_shell.dart checks session state and chooses sign-in or the employee shell
    ↓
3. Providers load app data from the shared API client
    ↓
4. Screens read provider state or call provider actions
    ↓
5. The UI rebuilds from the updated provider state
```

## Core Files

- [lib/main.dart](lib/main.dart): initializes Supabase and boots the app
- [lib/app_shell.dart](lib/app_shell.dart): switches between sign-in and the main app
- [lib/providers/api_client_provider.dart](lib/providers/api_client_provider.dart): exposes the shared API client
- [lib/providers/session_provider.dart](lib/providers/session_provider.dart): manages login state
- [lib/providers/dashboard_provider.dart](lib/providers/dashboard_provider.dart): loads dashboard data
- [lib/providers/notifications_provider.dart](lib/providers/notifications_provider.dart): loads and updates notifications
- [lib/providers/account_provider.dart](lib/providers/account_provider.dart): loads account and profile photo data
- [lib/services/api_client.dart](lib/services/api_client.dart): contains the backend calls
- [lib/services/api_client_contract.dart](lib/services/api_client_contract.dart): documents the backend API surface

## Step-by-Step Setup

### 1. Initialize Supabase and the app shell

The entrypoint already initializes Supabase and wraps the app in Riverpod:

```dart
await Supabase.initialize(
   url: _supabaseUrl,
   anonKey: _supabaseAnonKey,
);

runApp(const ProviderScope(child: AppShell()));
```

Use this pattern as the foundation for every backend call in the app.

### 2. Gate the app with session state

The session controller checks whether the current user has employee access before showing the main app.

```dart
final session = ref.watch(sessionControllerProvider);
final controller = ref.read(sessionControllerProvider.notifier);

if (session.isInitializing) {
   return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CircularProgressIndicator())),
   );
}

if (!session.isLoggedIn) {
   return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SignInScreen(onSignIn: controller.signIn),
   );
}
```

Example sign-in flow:

```dart
final error = await ref
      .read(sessionControllerProvider.notifier)
      .signIn(email, password);

if (error != null) {
   // Show the error to the user.
}
```

### 3. Read dashboard data through a provider

The dashboard provider loads dashboard metrics and notifications together.

```dart
final dashboardState = ref.watch(dashboardProvider);

dashboardState.when(
   loading: () => const CircularProgressIndicator(),
   error: (error, stack) => Text(error.toString()),
   data: (data) {
      final dashboard = data?['dashboard'] as Map<String, dynamic>?;
      final notifications = data?['notifications'] as List<dynamic>?;
      return Text('Loaded ${notifications?.length ?? 0} notifications');
   },
);
```

Refresh the dashboard after a user action:

```dart
await ref.read(dashboardProvider.notifier).refresh();
```

### 4. Load and manage notifications

The notifications controller converts backend rows into UI-ready notification items.

```dart
final notificationsState = ref.watch(notificationsControllerProvider);

notificationsState.when(
   loading: () => const CircularProgressIndicator(),
   error: (error, stack) => Text(error.toString()),
   data: (items) => ListView(
      children: items.map((item) => ListTile(title: Text(item.title))).toList(),
   ),
);
```

Common actions:

```dart
await ref.read(notificationsControllerProvider.notifier).markAllRead();
await ref.read(notificationsControllerProvider.notifier).markNotificationRead(notificationId);
await ref.read(notificationsControllerProvider.notifier).clearAll();
```

### 5. Load account data and profile photo state

The account provider loads the current account, and the profile photo provider fetches the image URL.

```dart
final accountAsync = ref.watch(accountProvider);
final profilePhotoAsync = ref.watch(profilePhotoProvider);

accountAsync.when(
   loading: () => const CircularProgressIndicator(),
   error: (error, stack) => Text(error.toString()),
   data: (account) => Text(account['name']?.toString() ?? 'Employee'),
);
```

Use the shared API client for profile and password actions:

```dart
final api = ref.read(apiClientProvider);

await api.uploadProfilePhoto(filePath: filePath);
await api.changePassword(
   currentPassword: currentPassword,
   newPassword: newPassword,
);
await api.updateAccount({'phone': '+63...'});
```

### 6. Call backend features directly when no dedicated provider exists

Some features currently use the API client directly. That is fine for one-off actions, but keep the UI thin and wrap the call in loading and error handling.

```dart
final api = ref.read(apiClientProvider);

final attendanceRows = await api.getAttendanceDtr();
final leaveSummary = await api.getLeaveMonitoring();
final credentials = await api.getEmployeeCredentials();
```

### 7. Follow the same pattern for write actions

When the app updates backend data, call the API client through a notifier or widget action, then refresh the affected provider.

```dart
final api = ref.read(apiClientProvider);

await api.markAllNotificationsRead();
await ref.read(notificationsControllerProvider.notifier).refreshNotifications();
```

## Provider Reference

### sessionControllerProvider

Use this provider to manage login and logout.

```dart
final error = await ref
      .read(sessionControllerProvider.notifier)
      .signIn(email, password);

await ref.read(sessionControllerProvider.notifier).signOut();
```

### dashboardProvider

Use this provider when you need dashboard data and the latest notifications together.

```dart
final dashboard = ref.watch(dashboardProvider);
await ref.read(dashboardProvider.notifier).refresh();
```

### notificationsControllerProvider

Use this provider for notification lists and notification actions.

```dart
final items = ref.watch(notificationsControllerProvider);
await ref.read(notificationsControllerProvider.notifier).markAllRead();
```

### accountProvider and profilePhotoProvider

Use these providers to load account details and the profile image URL.

```dart
final account = ref.watch(accountProvider);
final profilePhoto = ref.watch(profilePhotoProvider);
```

### apiClientProvider

Use this provider whenever you need the shared backend client.

```dart
final api = ref.read(apiClientProvider);
```

## Service Reference

The service layer is represented by [lib/services/api_client.dart](lib/services/api_client.dart) and the contract in [lib/services/api_client_contract.dart](lib/services/api_client_contract.dart).

### Authentication

```dart
await api.hasEmployeeAccess();
await api.login(email: email, password: password);
await api.logout();
```

### Dashboard and notifications

```dart
await api.getDashboard();
await api.getNotifications();
await api.markAllNotificationsRead();
await api.markNotificationRead(notificationId);
await api.clearAllNotifications();
```

### Account and profile

```dart
await api.getAccount();
await api.getProfilePhotoUrl();
await api.uploadProfilePhoto(filePath: filePath);
await api.changePassword(
   currentPassword: currentPassword,
   newPassword: newPassword,
);
await api.updateAccount(updates);
```

### Attendance and schedule

```dart
await api.getAttendanceDtr();
await api.getCurrentEmployeeScheduleSubmission();
await api.submitEmployeeSchedule(
   termLabel: termLabel,
   days: days,
);
```

### Leave and WFH

```dart
await api.getLeaveMonitoring();
await api.getWfhMonitoringSubmissions();
await api.submitWfhMonitoring(
   employeeId: employeeId,
   wfhDate: wfhDate,
   timeIn: timeIn,
   timeOut: timeOut,
   filePath: filePath,
);
```

### Credentials

```dart
await api.getEmployeeCredentials();
await api.getCredentialFileUrl(storedPath);
await api.uploadEmployeeCredentialFile(
   employeeId: employeeId,
   fileBytes: fileBytes,
   originalFileName: originalFileName,
);
await api.createEmployeeCredential(payload);
await api.deleteEmployeeCredential(id: id, filePath: filePath);
```

## Common Flow Examples

### Sign in and open the app

```dart
final error = await ref
      .read(sessionControllerProvider.notifier)
      .signIn(email, password);

if (error == null) {
   await ref.read(dashboardProvider.notifier).refresh();
}
```

### Refresh notifications after a backend update

```dart
await api.markNotificationRead(notificationId);
await ref.read(notificationsControllerProvider.notifier).refreshNotifications();
```

### Upload a profile photo and refresh account state

```dart
await api.uploadProfilePhoto(filePath: filePath);
ref.invalidate(accountProvider);
ref.invalidate(profilePhotoProvider);
```

## Setup Notes

- Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` through Dart defines.
- Keep user state behind the Riverpod session provider.
- Prefer shared services for backend calls instead of direct UI access.
- Enable Row Level Security on Supabase tables before production use.
- Validate input before sending it to the backend.

## Useful References

- [lib/main.dart](lib/main.dart)
- [lib/app_shell.dart](lib/app_shell.dart)
- [lib/providers](lib/providers)
- [lib/services](lib/services)
- [lib/screens](lib/screens)
- [pubspec.yaml](pubspec.yaml)
