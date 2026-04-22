#!/bin/bash

# 1. Cấu hình
PROJECT_NAME="kvx.xcodeproj"
SCHEME_NAME="kvx"

echo "🚀 Đang build dự án $SCHEME_NAME..."

# 2. Build dự án (Bỏ qua thư mục Index)
xcodebuild -project "$PROJECT_NAME" \
           -scheme "$SCHEME_NAME" \
           -sdk iphonesimulator \
           -configuration Debug build | xcpretty || xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME_NAME" -sdk iphonesimulator -configuration Debug build

if [ $? -ne 0 ]; then
    echo "❌ Build thất bại."
    exit 1
fi

echo "✅ Build thành công!"

# 3. Mở Simulator
open -a Simulator

# 4. Tìm đường dẫn file .app chuẩn (loại bỏ Index.noindex)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "$SCHEME_NAME.app" -type d | grep -v "Index.noindex" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Không tìm thấy file .app thực thi."
    exit 1
fi

# 5. Lấy Bundle Identifier
BUNDLE_ID=$(defaults read "$APP_PATH/Info.plist" CFBundleIdentifier)

if [ -z "$BUNDLE_ID" ]; then
    echo "❌ Không lấy được Bundle ID từ $APP_PATH"
    exit 1
fi

echo "📦 Đang cài đặt App: $BUNDLE_ID"
xcrun simctl install booted "$APP_PATH"

echo "🏃 Đang chạy App..."
xcrun simctl launch booted "$BUNDLE_ID"

echo "✨ Hoàn tất!"
