#!/bin/sh

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"

if ! rg -n 'account\.secondaryResetDescription' "$ROW_FILE" >/dev/null; then
  echo "FAIL: weekly reset description is not referenced in AccountRowView"
  exit 1
fi

if ! rg -n '7d 重置|7d:' "$ROW_FILE" >/dev/null; then
  echo "FAIL: weekly reset hint label is missing"
  exit 1
fi

echo "PASS: weekly reset hint is present"
