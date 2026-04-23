#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SERVICE_FILE="$ROOT/codexBar/Services/WhamService.swift"
MODEL_FILE="$ROOT/codexBar/Models/TokenAccount.swift"
BUILDER_FILE="$ROOT/codexBar/Services/AccountBuilder.swift"

if [[ ! -f "$SERVICE_FILE" || ! -f "$MODEL_FILE" || ! -f "$BUILDER_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n 'fetchAccountDetails' "$SERVICE_FILE" >/dev/null; then
  echo "FAIL: account refresh does not fetch account details"
  exit 1
fi

if ! rg -n 'entitlement.*expires_at|expires_at.*entitlement' "$SERVICE_FILE" >/dev/null; then
  echo "FAIL: account details refresh does not parse entitlement.expires_at"
  exit 1
fi

if ! rg -n 'parseISO8601Date' "$SERVICE_FILE" >/dev/null; then
  echo "FAIL: subscription expiry refresh does not parse ISO8601 expiry dates"
  exit 1
fi

if ! rg -n 'applyAccountDetails' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount cannot apply refreshed account details"
  exit 1
fi

if ! rg -n 'expiresAt = details\.subscriptionExpiresAt' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: refreshed subscription expiry is not written to TokenAccount.expiresAt"
  exit 1
fi

if ! rg -n 'subscriptionExpiryResolved' "$SERVICE_FILE" "$MODEL_FILE" >/dev/null; then
  echo "FAIL: refresh flow cannot distinguish missing expiry from failed detail refresh"
  exit 1
fi

if ! rg -n 'updated\.applyAccountDetails\(details\)' "$SERVICE_FILE" >/dev/null; then
  echo "FAIL: refresh flow does not apply refreshed account details"
  exit 1
fi

if ! rg -n 'static func parseISO8601Date' "$BUILDER_FILE" >/dev/null; then
  echo "FAIL: shared ISO8601 date parser is missing"
  exit 1
fi

echo "PASS: subscription expiry refresh is wired"
