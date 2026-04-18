#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
APP_NAME="codexAppBar.app"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}"
INSTALL_DIR="${1:-${HOME}/Applications}"
INSTALL_PATH="${INSTALL_DIR}/${APP_NAME}"

echo "==> Building ${APP_NAME} (unsigned Release)"
xcodebuild \
  -project "${ROOT}/codexBar.xcodeproj" \
  -scheme codexBar \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: build artifact not found: ${APP_PATH}" >&2
  exit 1
fi

echo "==> Installing to ${INSTALL_PATH}"
mkdir -p "${INSTALL_DIR}"
rm -rf "${INSTALL_PATH}"
cp -R "${APP_PATH}" "${INSTALL_PATH}"
xattr -dr com.apple.quarantine "${INSTALL_PATH}" 2>/dev/null || true

echo "==> Launching ${APP_NAME}"
open "${INSTALL_PATH}"

echo "Done."
