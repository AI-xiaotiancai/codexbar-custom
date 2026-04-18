#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MODEL_FILE="$ROOT/codexBar/Models/TokenAccount.swift"
ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"
L10N_FILE="$ROOT/codexBar/Localization.swift"

if [[ ! -f "$MODEL_FILE" || ! -f "$ROW_FILE" || ! -f "$L10N_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n 'resetNotActivated' "$L10N_FILE" >/dev/null; then
  echo "FAIL: missing localized inactive reset hint"
  exit 1
fi

if ! rg -n 'primaryResetStatusText|secondaryResetStatusText' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose reset status text"
  exit 1
fi

if ! rg -n 'primaryQuotaCard\(remainingPercent: 0, resetStatusText: account\.primaryResetStatusText\)|primaryQuotaCard\(remainingPercent: account\.primaryRemainingPercent, resetStatusText: account\.primaryResetStatusText\)|Text\(resetStatusText\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: 5h reset block does not use the new status text"
  exit 1
fi

if ! rg -n 'Text\(account\.secondaryResetStatusText\)' "$ROW_FILE" >/dev/null; then
  echo "FAIL: 7d reset block does not use the new status text"
  exit 1
fi

echo "PASS: inactive reset hint is wired"
