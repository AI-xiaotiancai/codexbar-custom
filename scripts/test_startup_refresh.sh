#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APP_FILE="$ROOT/codexBar/codexBarApp.swift"

if [[ ! -f "$APP_FILE" ]]; then
  echo "FAIL: codexBarApp.swift is missing"
  exit 1
fi

if ! rg -n 'applicationDidFinishLaunching' "$APP_FILE" >/dev/null; then
  echo "FAIL: app launch hook is missing"
  exit 1
fi

if ! rg -n 'WhamService\.shared\.refreshAll\(store: TokenStore\.shared\)' "$APP_FILE" >/dev/null; then
  echo "FAIL: app launch does not trigger an initial account refresh"
  exit 1
fi

if ! rg -n 'if !TokenStore\.shared\.accounts\.isEmpty' "$APP_FILE" >/dev/null; then
  echo "FAIL: startup refresh is not guarded for existing accounts"
  exit 1
fi

echo "PASS: app launch triggers an initial refresh for existing accounts"
