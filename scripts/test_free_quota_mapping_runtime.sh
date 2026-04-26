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

let future = Date().addingTimeInterval(7 * 24 * 3600)

let exhaustedFree = TokenAccount(
    email: "free@example.com",
    accountId: "free-1",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "free",
    primaryUsedPercent: 100,
    secondaryUsedPercent: 0,
    primaryResetAt: future,
    secondaryResetAt: nil
)

expect(exhaustedFree.showsPrimaryQuota == false, "free account still exposes a primary quota card")
expect(exhaustedFree.effectiveWeeklyUsedPercent == 100, "free account weekly usage is not mapped from the real free quota window")
expect(exhaustedFree.effectiveWeeklyRemainingPercent == 0, "exhausted free account does not show 0% weekly remaining")
expect(exhaustedFree.effectiveWeeklyResetStatusText != L.resetNotActivated, "exhausted free account still looks inactive")

let inactiveFree = TokenAccount(
    email: "free2@example.com",
    accountId: "free-2",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "free",
    primaryUsedPercent: 0,
    secondaryUsedPercent: 0,
    primaryResetAt: nil,
    secondaryResetAt: nil
)

expect(inactiveFree.showsPrimaryQuota == false, "inactive free account still exposes a primary quota card")
expect(inactiveFree.effectiveWeeklyRemainingPercent == 100, "inactive free account weekly remaining should stay at 100%")
expect(inactiveFree.effectiveWeeklyResetStatusText == L.resetNotActivated, "inactive free account should show the not-activated hint")

let plus = TokenAccount(
    email: "plus@example.com",
    accountId: "plus-1",
    accessToken: "token",
    refreshToken: "refresh",
    idToken: "id",
    planType: "plus",
    primaryUsedPercent: 25,
    secondaryUsedPercent: 40,
    primaryResetAt: future.addingTimeInterval(-2 * 24 * 3600),
    secondaryResetAt: future
)

expect(plus.showsPrimaryQuota == true, "plus account lost its 5h quota card")
expect(plus.effectiveWeeklyUsedPercent == 40, "plus weekly usage should still come from the 7d window")

print("PASS: free quota mapping uses a single weekly window without a fake 5h card")
SWIFT

swiftc \
  "$ROOT/codexBar/Localization.swift" \
  "$ROOT/codexBar/Models/TokenAccount.swift" \
  "$ROOT/codexBar/Services/TokenStore.swift" \
  "$ROOT/codexBar/Services/WhamService.swift" \
  "$TMP_DIR/main.swift" \
  -o "$TMP_DIR/test_free_quota_mapping"

"$TMP_DIR/test_free_quota_mapping"
