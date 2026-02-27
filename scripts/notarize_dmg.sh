#!/bin/zsh
set -euo pipefail

APP_NAME="DevWispr"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"

# Credentials (choose ONE approach)
# 1) Apple ID + app-specific password:
#   export NOTARY_APPLE_ID="you@domain.com"
#   export NOTARY_TEAM_ID="TEAMID"
#   export NOTARY_PASSWORD="app-specific-password"
# 2) Keychain profile (recommended):
#   xcrun notarytool store-credentials "wispr-notary" --apple-id "you@domain.com" --team-id "TEAMID" --password "app-specific-password"
#   export NOTARY_KEYCHAIN_PROFILE="wispr-notary"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" --wait
else
  : "${NOTARY_APPLE_ID:?Set NOTARY_APPLE_ID or NOTARY_KEYCHAIN_PROFILE}"
  : "${NOTARY_TEAM_ID:?Set NOTARY_TEAM_ID or NOTARY_KEYCHAIN_PROFILE}"
  : "${NOTARY_PASSWORD:?Set NOTARY_PASSWORD or NOTARY_KEYCHAIN_PROFILE}"

  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${NOTARY_APPLE_ID}" \
    --team-id "${NOTARY_TEAM_ID}" \
    --password "${NOTARY_PASSWORD}" \
    --wait
fi

xcrun stapler staple "${DMG_PATH}"

echo "Notarized and stapled: ${DMG_PATH}"
