# NUHRIS Mobile App

NUHRIS Mobile App is the HRIS self-service application for National University Lipa. It enables employees to manage attendance and DTR records, submit credentials, monitor leave-related items, and access core account and notification features from a single Flutter app.

## Overview

This repository contains the mobile and web-ready Flutter client for NUHRIS.
It connects to backend HR services and provides employee-focused workflows such as:

- Attendance and Daily Time Record (DTR) viewing
- Credential upload and submission for HR review
- Leave and work monitoring modules
- Notification center and account management

## Tech Stack

- Flutter (Dart)
- Material UI components
- API-driven data access through shared service clients
- Multi-platform targets: Android, iOS, and Web

## Project Structure

- lib/: Application source code (screens, widgets, services, theme, navigation)
- assets/: Static assets (images and related resources)
- android/: Android platform configuration
- ios/: iOS platform configuration
- web/: Web entry assets and manifest
- backend/: Backend-related resources used by this project

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode (for mobile targets)

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

The app initializes Supabase from compile-time Dart defines in `lib/main.dart`.

Required values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If no values are passed, the app falls back to the default Supabase project currently hardcoded in `main.dart`.

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

## Git Hooks

This repo includes a local Git hook that strips the Copilot co-author trailer from commit messages.

Enable once in this repository:

```bash
git config core.hooksPath .githooks
```
