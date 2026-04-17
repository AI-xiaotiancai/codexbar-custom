#!/bin/sh

set -eu

MODEL_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Models/TokenAccount.swift"
ROW_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/AccountRowView.swift"
CONTENT_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/ContentView.swift"
APP_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/codexBarApp.swift"

if ! rg -n 'primaryRemainingPercent|secondaryRemainingPercent' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: remaining quota fields are missing in TokenAccount"
  exit 1
fi

if rg -n 'account\.primaryUsedPercent\)\)%|account\.secondaryUsedPercent\)\)%' "$ROW_FILE" >/dev/null; then
  echo "FAIL: AccountRowView still displays used quota percentages"
  exit 1
fi

if rg -n 'active\\.primaryUsedPercent|active\\.secondaryUsedPercent' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: ContentView still displays used quota percentages"
  exit 1
fi

if rg -n 'active\\.primaryUsedPercent|active\\.secondaryUsedPercent' "$APP_FILE" >/dev/null; then
  echo "FAIL: Menu bar icon still displays used quota percentages"
  exit 1
fi

echo "PASS: remaining quota display is wired"
