#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat >"$TMP_DIR/main.swift" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

L.languageOverride = true

let base = Date(timeIntervalSince1970: 1_700_000_000)

var account = TokenAccount(
    email: "test@example.com",
    accountId: "acct_1",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "plus",
    primaryUsedPercent: 0,
    secondaryUsedPercent: 0,
    primaryResetAt: base.addingTimeInterval(5 * 3600),
    secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600),
    lastChecked: base
)

account.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 0,
        secondaryUsedPercent: 0,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 120),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 120)
    ),
    checkedAt: base.addingTimeInterval(120)
)

expect(account.primaryResetStatusText != L.resetNotActivated, "primary reset was marked inactive after only one stagnant refresh")
expect(account.secondaryResetStatusText != L.resetNotActivated, "secondary reset was marked inactive after only one stagnant refresh")

account.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 0,
        secondaryUsedPercent: 0,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 240),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 240)
    ),
    checkedAt: base.addingTimeInterval(240)
)

expect(account.primaryResetStatusText == L.resetNotActivated, "primary reset did not fall back to inactive after repeated stagnant refreshes")
expect(account.secondaryResetStatusText == L.resetNotActivated, "secondary reset did not fall back to inactive after repeated stagnant refreshes")

account.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 0,
        secondaryUsedPercent: 0,
        primaryResetAt: base.addingTimeInterval(240).addingTimeInterval(5 * 3600 - 180),
        secondaryResetAt: base.addingTimeInterval(240).addingTimeInterval(7 * 24 * 3600 - 180)
    ),
    checkedAt: base.addingTimeInterval(360)
)

expect(account.primaryResetStatusText != L.resetNotActivated, "primary reset did not recover after the countdown started decreasing again")
expect(account.secondaryResetStatusText != L.resetNotActivated, "secondary reset did not recover after the countdown started decreasing again")

var activeQuotaAccount = TokenAccount(
    email: "active@example.com",
    accountId: "acct_2",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "plus",
    primaryUsedPercent: 36,
    secondaryUsedPercent: 12,
    primaryResetAt: base.addingTimeInterval(5 * 3600),
    secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600),
    lastChecked: base
)

activeQuotaAccount.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 36,
        secondaryUsedPercent: 12,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 120),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 120)
    ),
    checkedAt: base.addingTimeInterval(120)
)

activeQuotaAccount.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 36,
        secondaryUsedPercent: 12,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 240),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 240)
    ),
    checkedAt: base.addingTimeInterval(240)
)

expect(activeQuotaAccount.primaryResetStatusText != L.resetNotActivated, "primary reset was marked inactive even though the 5h quota has already been used")
expect(activeQuotaAccount.secondaryResetStatusText != L.resetNotActivated, "secondary reset was marked inactive even though the 7d quota has already been used")

var linkedActivationAccount = TokenAccount(
    email: "linked@example.com",
    accountId: "acct_3",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "plus",
    primaryUsedPercent: 36,
    secondaryUsedPercent: 0,
    primaryResetAt: base.addingTimeInterval(5 * 3600),
    secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600),
    lastChecked: base
)

linkedActivationAccount.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 36,
        secondaryUsedPercent: 0,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 120),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 120)
    ),
    checkedAt: base.addingTimeInterval(120)
)

linkedActivationAccount.applyUsage(
    result: WhamUsageResult(
        planType: "plus",
        primaryUsedPercent: 36,
        secondaryUsedPercent: 0,
        primaryResetAt: base.addingTimeInterval(5 * 3600 + 240),
        secondaryResetAt: base.addingTimeInterval(7 * 24 * 3600 + 240)
    ),
    checkedAt: base.addingTimeInterval(240)
)

expect(linkedActivationAccount.secondaryResetStatusText != L.resetNotActivated, "secondary reset was marked inactive even though the account is already active via the 5h window")

print("PASS: stagnant reset windows fall back to inactive and recover when countdown resumes")
SWIFT

swiftc \
  "$ROOT/codexBar/Localization.swift" \
  "$ROOT/codexBar/Models/TokenAccount.swift" \
  "$ROOT/codexBar/Services/TokenStore.swift" \
  "$ROOT/codexBar/Services/WhamService.swift" \
  "$TMP_DIR/main.swift" \
  -o "$TMP_DIR/test_stagnant_reset"

"$TMP_DIR/test_stagnant_reset"
