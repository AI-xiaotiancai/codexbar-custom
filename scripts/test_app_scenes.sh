#!/bin/sh

set -eu

APP_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/codexBarApp.swift"
CONTROLLER_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Services/MenuBarStatusController.swift"

if [[ ! -f "$CONTROLLER_FILE" ]]; then
  echo "FAIL: MenuBarStatusController.swift is missing"
  exit 1
fi

if ! rg -n 'WindowGroup' "$APP_FILE" >/dev/null; then
  echo "FAIL: WindowGroup is missing; Dock app may not present a stable primary scene"
  exit 1
fi

if ! rg -n 'MenuBarStatusController\.shared\.install\(\)' "$APP_FILE" >/dev/null; then
  echo "FAIL: app does not install the dedicated menu bar status controller"
  exit 1
fi

echo "PASS: app defines both WindowGroup and the dedicated menu bar status controller"
