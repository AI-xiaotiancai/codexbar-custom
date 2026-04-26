#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SERVICE_FILE="$ROOT/codexBar/Services/WhamService.swift"
MODEL_FILE="$ROOT/codexBar/Models/TokenAccount.swift"
BUILDER_FILE="$ROOT/codexBar/Services/AccountBuilder.swift"
STORE_FILE="$ROOT/codexBar/Services/TokenStore.swift"
ROW_FILE="$ROOT/codexBar/Views/AccountRowView.swift"
MENU_FILE="$ROOT/codexBar/Views/MenuBarView.swift"
STATUS_FILE="$ROOT/codexBar/Services/MenuBarStatusController.swift"

if [[ ! -f "$SERVICE_FILE" || ! -f "$MODEL_FILE" || ! -f "$BUILDER_FILE" || ! -f "$STORE_FILE" || ! -f "$ROW_FILE" || ! -f "$MENU_FILE" || ! -f "$STATUS_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n -F 'var showsPrimaryQuota: Bool' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose plan-aware primary quota visibility"
  exit 1
fi

if ! rg -n -F 'var effectiveWeeklyUsedPercent: Double' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose an effective weekly quota accessor"
  exit 1
fi

if ! rg -n -F 'var effectiveWeeklyResetAt: Date?' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose the effective weekly reset anchor"
  exit 1
fi

if ! rg -n -F 'var effectiveWeeklyResetStatusText: String' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: TokenAccount does not expose the effective weekly reset status text"
  exit 1
fi

if rg -n -F 'freePrimaryInactiveSignal' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: free accounts still rely on the fake 5h inactive signal"
  exit 1
fi

if rg -n 'primaryUsedPercent = 0|primaryResetAt = nil|secondaryUsedPercent = 0|secondaryResetAt = nil' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: free-account normalization still clears persisted quota windows"
  exit 1
fi

if rg -n -F 'primaryCandidateUsedPercent >= 100' "$SERVICE_FILE" >/dev/null; then
  echo "FAIL: WhamService still rewrites the free primary window into an inactive state"
  exit 1
fi

if ! rg -n -F 'guard !isFreePlan, let expiresAt else { return nil }' "$MODEL_FILE" >/dev/null; then
  echo "FAIL: free accounts still expose subscription expiry text"
  exit 1
fi

if rg -n -F 'expiresAt: expiresAt ?? tokenExpiresAt' "$BUILDER_FILE" >/dev/null; then
  echo "FAIL: account builder still falls back to token expiry as subscription expiry"
  exit 1
fi

if ! rg -n -F 'if account.showsPrimaryQuota' "$ROW_FILE" >/dev/null; then
  echo "FAIL: AccountRowView does not gate the 5h card by plan-aware visibility"
  exit 1
fi

if ! rg -n -F 'effectiveWeeklyResetStatusText' "$ROW_FILE" >/dev/null; then
  echo "FAIL: AccountRowView is not using the effective weekly reset status"
  exit 1
fi

if ! rg -n -F 'showsPrimaryQuota' "$MENU_FILE" >/dev/null; then
  echo "FAIL: MenuBarView auto-switching is not plan-aware"
  exit 1
fi

if ! rg -n -F 'effectiveWeeklyRemainingPercent' "$STATUS_FILE" >/dev/null; then
  echo "FAIL: MenuBarStatusController status text is not using the effective weekly quota"
  exit 1
fi

if ! rg -n -F 'sanitized.sanitizePersistedState()' "$STORE_FILE" >/dev/null || ! rg -n -F 'sanitizedAccount.sanitizePersistedState()' "$STORE_FILE" >/dev/null; then
  echo "FAIL: TokenStore does not sanitize persisted free-account state on load/update"
  exit 1
fi

echo "PASS: free account state normalization is wired for plan-aware weekly quota handling"
