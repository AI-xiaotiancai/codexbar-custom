#!/bin/bash
set -euo pipefail

MODEL_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Models/TokenAccount.swift"
MENU_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/MenuBarView.swift"
CONTENT_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/ContentView.swift"

if [[ ! -f "$MODEL_FILE" || ! -f "$MENU_FILE" || ! -f "$CONTENT_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n 'var displaySortRank: Int' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not define a shared displaySortRank"
  exit 1
fi

if ! rg -n 'if isActive \{ return 0 \}' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: active account is not explicitly pinned to the top"
  exit 1
fi

if ! rg -n 'if quotaExhausted \{ return 3 \}' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: quota exhausted accounts are not explicitly pushed to the bottom"
  exit 1
fi

if ! rg -n 'displaySortRank' "$MENU_FILE" >/dev/null; then
  echo "FAIL: menu bar sorting does not use shared displaySortRank"
  exit 1
fi

if ! rg -n 'displaySortRank' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: main window sorting does not use shared displaySortRank"
  exit 1
fi

echo "PASS: account sorting uses shared top/bottom priority"
