#!/bin/sh

set -eu

ROW_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/AccountRowView.swift"

if ! rg -n '5h 剩余|7d 剩余' "$ROW_FILE" >/dev/null; then
  echo "FAIL: remaining labels are missing from AccountRowView"
  exit 1
fi

echo "PASS: remaining labels are present"
