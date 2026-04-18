#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"
MODEL_FILE="$ROOT/codexBar/Models/TokenAccount.swift"
L10N_FILE="$ROOT/codexBar/Localization.swift"

if [[ ! -f "$ROW_FILE" || ! -f "$MODEL_FILE" || ! -f "$L10N_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n 'subscriptionExpiryText' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose a formatted subscription expiry text"
  exit 1
fi

if ! rg -n 'dateFormat = .*yyyy-MM-dd HH:mm' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: subscription expiry text is not formatted with date and time"
  exit 1
fi

if ! rg -n 'subscriptionExpiryLabel' "$L10N_FILE" >/dev/null; then
  echo "FAIL: subscription expiry label is not localized"
  exit 1
fi

if ! rg -n 'subscriptionExpiryText|subscriptionExpiryColor' "$ROW_FILE" >/dev/null; then
  echo "FAIL: AccountRowView does not render inline subscription expiry with warning colors"
  exit 1
fi

if rg -n 'return String\(account\.accountId\.prefix\(8\)\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: AccountRowView still falls back to the 8-character account id prefix"
  exit 1
fi

echo "PASS: account rows display compact subscription expiry information with urgency colors"
