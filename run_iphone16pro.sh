#!/bin/bash

set -e

# Script to build and run KVx app on iPhone 16 Pro simulator

PROJECT_DIR="$(cd "$(dirname "$0")/kvx_flutter" && pwd)"

cd "$PROJECT_DIR"

echo "=== Building KVx for iOS (iPhone 16 Pro Simulator) ==="

# Get list of available simulators
echo "Available simulators:"
xcrun simctl list devices available | grep -E "iPhone" | head -10

# Boot iPhone 16 Pro simulator if not running
SIMULATOR_NAME="iPhone 16 Pro"
SIMULATOR_ID="65A80E5B-E316-471D-9BD7-E1B9D8FF2D01"

SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep "Booted" || true)

if [ -z "$SIMULATOR_STATE" ]; then
    echo ""
    echo "Booting $SIMULATOR_NAME simulator..."
    xcrun simctl boot "$SIMULATOR_ID"
    echo "Simulator booted."
else
    echo "$SIMULATOR_NAME is already booted."
fi

# Open Simulator app (optional, for visual feedback)
open -a Simulator 2>/dev/null || true

echo ""
echo "Building and running Flutter app..."
echo ""

# Build and run using device ID (more reliable)
flutter run -d "$SIMULATOR_ID"

echo ""
echo "Done!"
