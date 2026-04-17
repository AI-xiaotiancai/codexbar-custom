#!/bin/bash
set -euo pipefail

ROW_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/AccountRowView.swift"

if [[ ! -f "$ROW_FILE" ]]; then
  echo "FAIL: AccountRowView.swift is missing"
  exit 1
fi

if ! rg -n 'Text\("5h 重置: " \+ account\.primaryResetDescription\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: 5h reset hint is not shown in the unified quota block"
  exit 1
fi

if ! rg -n 'Text\("7d 重置: " \+ account\.secondaryResetDescription\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: 7d reset hint is not shown in the unified quota block"
  exit 1
fi

if rg -n 'Text\("5h: " \+ account\.primaryResetDescription\)|Text\("7d: " \+ account\.secondaryResetDescription\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: legacy split reset hints still exist outside the unified quota block"
  exit 1
fi

echo "PASS: unified reset display is present"
