#!/usr/bin/env bash
# Builds the signed, obfuscated NUHRIS release APK.
#
#   LARAVEL_BASE_URL=https://hris.example.edu tool/build_release.sh
#
# Requirements:
#   * android/key.properties + the release keystore (never committed).
#   * LARAVEL_BASE_URL, if set, must be https:// (release builds also reject
#     http:// at runtime; see AppConfig.secureBaseUrl).
#
# Dart symbols are written to release-symbols/<version>/ (git-ignored).
# Archive that folder for every released build: it is required to decode
# obfuscated crash stack traces (`flutter symbolize`).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f android/key.properties ]]; then
  echo "error: android/key.properties is missing (release signing)." >&2
  exit 1
fi

url="${LARAVEL_BASE_URL:-}"
if [[ -n "$url" && "$url" != https://* ]]; then
  echo "error: LARAVEL_BASE_URL must use https:// for release builds." >&2
  exit 1
fi
if [[ -z "$url" ]]; then
  echo "warning: LARAVEL_BASE_URL not set; Academic Calendar and password" \
       "reset will be unavailable in this build." >&2
fi

version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
symbols="release-symbols/${version}"
mkdir -p "$symbols"

flutter build apk --release \
  --obfuscate \
  --split-debug-info="$symbols" \
  --dart-define=LARAVEL_BASE_URL="$url"

echo "APK:     build/app/outputs/flutter-apk/app-release.apk"
echo "Symbols: $symbols (archive these with the release)"
