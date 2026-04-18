#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"

if [[ ! -f "$ROW_FILE" ]]; then
  echo "FAIL: AccountRowView.swift is missing"
  exit 1
fi

if ! rg -n 'account\.primaryExhausted && !account\.secondaryExhausted' "$ROW_FILE" >/dev/null; then
  echo "FAIL: primary-only exhausted case is not handled explicitly"
  exit 1
fi

if ! rg -n 'Text\("7d 剩余"\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: weekly quota card label is missing"
  exit 1
fi

if ! rg -n 'weeklyQuotaCard' "$ROW_FILE" >/dev/null; then
  echo "FAIL: primary-only exhausted case does not keep the full weekly card"
  exit 1
fi

if ! rg -n 'primaryQuotaCard\(remainingPercent: 0' "$ROW_FILE" >/dev/null; then
  echo "FAIL: primary-only exhausted case does not render the 5h side as a 0% quota card"
  exit 1
fi

if rg -n 'primaryExhaustedCard' "$ROW_FILE" >/dev/null; then
  echo "FAIL: primary-only exhausted case still uses the dedicated exhausted warning card"
  exit 1
fi

echo "PASS: primary exhausted accounts keep both quota cards, with 5h rendered as 0%"
