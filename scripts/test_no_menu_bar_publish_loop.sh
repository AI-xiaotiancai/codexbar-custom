#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APP_FILE="$ROOT/codexBar/codexBarApp.swift"
SETTINGS_FILE="$ROOT/codexBar/Services/AppSettings.swift"

if [[ ! -f "$APP_FILE" || ! -f "$SETTINGS_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if rg -n 'MenuBarExtra\(isInserted:' "$APP_FILE" >/dev/null; then
  echo "FAIL: MenuBarExtra still binds insertion state, which can trigger SwiftUI publish loops"
  exit 1
fi

if rg -n 'ensureMenuBarVisible' "$APP_FILE" >/dev/null; then
  echo "FAIL: App lifecycle still forces menu bar reinsertion during scene updates"
  exit 1
fi

if rg -n 'showMenuBarIcon' "$SETTINGS_FILE" >/dev/null; then
  echo "FAIL: AppSettings still persists menu bar insertion state"
  exit 1
fi

echo "PASS: menu bar publish loop hooks are removed"
