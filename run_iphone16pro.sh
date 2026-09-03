#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/kvx_flutter"
SIMULATOR_NAME="iPhone 16 Pro"
SIMULATOR_ID="65A80E5B-E316-471D-9BD7-E1B9D8FF2D01"
APP_PATH="$PROJECT_DIR/build/ios/iphonesimulator/Runner.app"
BUNDLE_ID="com.kvx.kvxFlutter"

if [[ -z "${BINBLOG_USERNAME:-}" || -z "${BINBLOG_PASSWORD:-}" ]]; then
    echo "Set BINBLOG_USERNAME and BINBLOG_PASSWORD before running."
    exit 1
fi

if ! xcrun simctl list devices | grep -q "$SIMULATOR_ID"; then
    echo "Simulator not found: $SIMULATOR_NAME ($SIMULATOR_ID)"
    exit 1
fi

cd "$PROJECT_DIR"

echo "=== Building KVX Flutter for $SIMULATOR_NAME ==="

if ! xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -q "Booted"; then
    echo "Booting $SIMULATOR_NAME..."
    xcrun simctl boot "$SIMULATOR_ID"
fi
xcrun simctl bootstatus "$SIMULATOR_ID" -b

open -a Simulator 2>/dev/null || true

echo "Installing Flutter dependencies..."
flutter pub get

echo "Building simulator app..."
flutter build ios --simulator \
    --dart-define="BINBLOG_USERNAME=$BINBLOG_USERNAME" \
    --dart-define="BINBLOG_PASSWORD=$BINBLOG_PASSWORD"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Build succeeded but app was not found: $APP_PATH"
    exit 1
fi

echo "Installing and launching $BUNDLE_ID..."
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo "Done. Flutter app is running on $SIMULATOR_NAME."
