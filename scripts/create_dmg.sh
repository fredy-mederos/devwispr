#!/bin/zsh
set -euo pipefail

APP_NAME="DevWispr"
CONFIGURATION="Release"

# Signing identity (override via env)
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-Developer ID Application: YOUR NAME (TEAMID)}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
DMG_STAGING="${BUILD_DIR}/dmg-staging"
DMG_RAW="${BUILD_DIR}/${APP_NAME}-raw.dmg"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

# Build the app
xcodebuild \
  -project "${ROOT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  build

ENTITLEMENTS="${ROOT_DIR}/DevWispr/DevWispr.entitlements"

# Re-sign with Developer ID, explicitly passing the entitlements file.
# Without --entitlements the sandbox/audio-input entitlements are stripped,
# which silently prevents macOS from showing the microphone permission dialog.
codesign --force --options runtime --deep \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${APP_SIGN_IDENTITY}" \
  "${APP_PATH}"

# Verify signature
codesign --verify --deep --strict "${APP_PATH}"

# Prepare staging folder
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

# Create a writable DMG from staging folder
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDRW \
  "${DMG_RAW}"

# Convert to read-only compressed DMG
rm -f "${DMG_PATH}"
hdiutil convert "${DMG_RAW}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${DMG_PATH}"

# Sign the DMG itself
codesign --force --sign "${APP_SIGN_IDENTITY}" "${DMG_PATH}"

# Clean up
rm -rf "${DMG_STAGING}" "${DMG_RAW}"

echo "Created signed DMG at: ${DMG_PATH}"
