#!/bin/sh

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MODEL_FILE="$ROOT/codexBar/Models/TokenAccount.swift"
ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"
CONTENT_FILE="$ROOT/codexBar/ContentView.swift"
APP_FILE="$ROOT/codexBar/codexBarApp.swift"

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
