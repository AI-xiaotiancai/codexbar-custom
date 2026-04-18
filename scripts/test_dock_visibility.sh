#!/bin/sh

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PROJECT_FILE="$ROOT/codexBar.xcodeproj/project.pbxproj"

if rg -n 'INFOPLIST_KEY_LSUIElement = YES;' "$PROJECT_FILE" >/dev/null; then
  echo "FAIL: Dock icon is disabled by INFOPLIST_KEY_LSUIElement = YES"
  exit 1
fi

echo "PASS: Dock icon is enabled"
