#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIMULATOR_ID="${SIMULATOR_ID:-65A80E5B-E316-471D-9BD7-E1B9D8FF2D01}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_DIR/build/native-derived}"

# Build and install the same output; never pick an arbitrary app from DerivedData.
xcodebuild -project "$PROJECT_DIR/kvx.xcodeproj" -scheme kvx \
  -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" CODE_SIGNING_ALLOWED=NO build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/kvx.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Không tìm thấy bản vừa build: $APP_PATH" >&2
  exit 1
fi

# bootstatus waits for a usable simulator and boots it if necessary.
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" com.kvx.kvx
echo "Đã cài và chạy bản native mới nhất. Đăng nhập Binblog trong ứng dụng để tải thiết bị."
