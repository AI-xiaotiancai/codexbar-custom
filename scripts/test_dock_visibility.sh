#!/bin/sh

set -eu

PROJECT_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar.xcodeproj/project.pbxproj"

if rg -n 'INFOPLIST_KEY_LSUIElement = YES;' "$PROJECT_FILE" >/dev/null; then
  echo "FAIL: Dock icon is disabled by INFOPLIST_KEY_LSUIElement = YES"
  exit 1
fi

echo "PASS: Dock icon is enabled"
