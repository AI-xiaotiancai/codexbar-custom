#!/bin/sh

set -eu

SETTINGS_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Services/AppSettings.swift"
APP_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/codexBarApp.swift"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "FAIL: AppSettings.swift is missing"
  exit 1
fi

if ! rg -n 'showDockIcon' "$SETTINGS_FILE" >/dev/null; then
  echo "FAIL: showDockIcon setting is missing"
  exit 1
fi

if ! rg -n 'setActivationPolicy' "$SETTINGS_FILE" >/dev/null; then
  echo "FAIL: activation policy is not applied from settings"
  exit 1
fi

if ! rg -n '@StateObject private var settings = AppSettings.shared' "$APP_FILE" >/dev/null; then
  echo "FAIL: app does not own shared settings"
  exit 1
fi

echo "PASS: display mode settings are wired"
