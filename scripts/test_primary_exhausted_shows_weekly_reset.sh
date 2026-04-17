#!/bin/bash
set -euo pipefail

ROW_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/AccountRowView.swift"

if [[ ! -f "$ROW_FILE" ]]; then
  echo "FAIL: AccountRowView.swift is missing"
  exit 1
fi

if ! rg -n 'else if account\.quotaExhausted' "$ROW_FILE" >/dev/null; then
  echo "FAIL: quota exhausted branch is missing"
  exit 1
fi

if ! rg -n 'account\.primaryExhausted && !account\.secondaryExhausted' "$ROW_FILE" >/dev/null; then
  echo "FAIL: primary-only exhausted case is not handled explicitly"
  exit 1
fi

if ! rg -n 'Text\(account\.secondaryResetStatusText\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: weekly reset hint is not shown for the primary-only exhausted case"
  exit 1
fi

echo "PASS: primary exhausted accounts still show weekly reset hint"
