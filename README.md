# NUHRIS Mobile App

NUHRIS Mobile App is the HRIS self-service client for National University Lipa. It provides employees with a single Flutter app for attendance and DTR viewing, credential submission, leave and WFH monitoring, notifications, and account/profile management.

## What's Included

This repository contains the mobile and web-ready Flutter client for NUHRIS.
The app is built around Riverpod state management and a Supabase-backed data layer, with employee-focused workflows such as:

- Attendance and Daily Time Record (DTR) viewing
- Credential upload, review, and file preview
- Leave and work-from-home monitoring
- Notifications and app-wide session handling
- Account details, profile photo upload, and password changes
- Sign-in, forgot password, and email verification flows

## App Stack

- Flutter (Dart)
- Riverpod for state management
- Supabase for authentication and data access
- Material UI components with Google Fonts
- Image capture and cropping via `image_picker` and `image_cropper`
- File upload and preview support via `file_picker` and `webview_flutter`
- Multi-platform targets: Android, iOS, and Web

## Backend Integration

See [BACKEND_INTEGRATION.md](BACKEND_INTEGRATION.md) for the separate backend setup guide, service flow, and integration notes.

## Project Structure

- lib/: Application source code (app shell, providers, screens, services, theme, navigation, widgets)
- assets/: Static assets such as images
- android/: Android platform configuration
- ios/: iOS platform configuration
- web/: Web entry assets and manifest
- backend/: Backend-related resources and integration notes used by this project

## Main App Flow

```text
1. App starts
   ↓
2. Supabase initializes from compile-time Dart defines
   ↓
3. Riverpod session state decides which screen to show
   ↓
4. User signs in or continues into the employee shell
   ↓
5. Screens load data from shared services and providers
```

### Primary Screens

- Dashboard
- Attendance / DTR
- Credentials
- Leave Monitoring
- WFH Monitoring
- Notifications
- Account / Profile
- Authentication screens for sign in and password recovery

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK bundled with Flutter
- Android Studio / Xcode for mobile targets

### Installation

1. Clone the repository.
2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

For web:

```bash
flutter run -d chrome
```

## Build

Build an Android APK:

```bash
flutter build apk
```

Build web assets:

```bash
flutter build web
```

## Environment / Config

The app initializes Supabase from compile-time Dart defines in [lib/main.dart](lib/main.dart).
The entrypoint wraps the app in a Riverpod [ProviderScope](lib/main.dart), and [lib/app_shell.dart](lib/app_shell.dart) controls whether the user sees sign-in or the main app shell.

Required values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If no values are passed, the app falls back to the default Supabase project currently hardcoded in [lib/main.dart](lib/main.dart).

Run the app with custom configuration like this:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

For web:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Security Notes

- Do not hardcode real credentials in the app.
- Prefer Supabase Auth for sign-in and password recovery.
- Enable Row Level Security on Supabase tables before production use.
- Validate user input before sending it to the backend.
- Keep profile and file upload flows behind authenticated sessions.

## Troubleshooting

### App does not open after sign in
- Check that the session provider is returning a logged-in state.
- Confirm Supabase credentials are valid.
- Inspect the browser or device console for auth errors.

### Data is not loading
- Verify the backend tables contain data.
- Check the relevant service or provider in `lib/providers/` and `lib/services/`.
- Confirm network access and Supabase project availability.

### Profile photo upload fails
- Make sure camera or gallery permissions are allowed.
- Verify the selected file is supported and the cropper completes successfully.
- Check the authenticated Supabase session before uploading.

### File preview or upload issues
- Confirm the file picker returned a valid file.
- Check the target platform supports the selected preview flow.
- Re-run `flutter pub get` after dependency changes.

## Git Hooks

This repo includes a local Git hook that strips the Copilot co-author trailer from commit messages.

Enable it once in this repository:

```bash
git config core.hooksPath .githooks
```

## Useful References

- [lib/main.dart](lib/main.dart)
- [lib/app_shell.dart](lib/app_shell.dart)
- [lib/providers](lib/providers)
- [lib/screens](lib/screens)
- [pubspec.yaml](pubspec.yaml)
- [BACKEND_INTEGRATION.md](BACKEND_INTEGRATION.md)
