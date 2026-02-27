#!/bin/zsh
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

: "${APP_SIGN_IDENTITY:?Set APP_SIGN_IDENTITY env var (e.g. 'Developer ID Application: Your Name (TEAMID)')}"
export APP_SIGN_IDENTITY

echo "==> Building and signing DMG..."
"${SCRIPTS_DIR}/create_dmg.sh"

echo "==> Notarizing and stapling..."
"${SCRIPTS_DIR}/notarize_dmg.sh"

echo "==> Done."
open "${SCRIPTS_DIR}/../build"
