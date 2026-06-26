#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE_FILE="$ROOT/codexBar/Services/TokenStore.swift"
APP_FILE="$ROOT/codexBar/codexBarApp.swift"
CONTENT_FILE="$ROOT/codexBar/ContentView.swift"
MENU_FILE="$ROOT/codexBar/Views/MenuBarView.swift"

if [[ ! -f "$STORE_FILE" || ! -f "$APP_FILE" || ! -f "$CONTENT_FILE" || ! -f "$MENU_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n -F 'func reconcileWithCurrentAuth()' "$STORE_FILE" >/dev/null; then
  echo "FAIL: TokenStore is missing reconcileWithCurrentAuth()"
  exit 1
fi

if ! rg -n 'tokenExpired = false|token_expired = false' "$STORE_FILE" >/dev/null; then
  echo "FAIL: reconcile path does not clear token_expired for the active account"
  exit 1
fi

if ! rg -n 'isSuspended = false|is_suspended = false' "$STORE_FILE" >/dev/null; then
  echo "FAIL: reconcile path does not clear is_suspended for the active account"
  exit 1
fi

if ! rg -n 'accessToken = .*access_token|refreshToken = .*refresh_token|idToken = .*id_token' "$STORE_FILE" >/dev/null; then
  echo "FAIL: reconcile path does not refresh stored tokens from auth.json"
  exit 1
fi

if ! rg -n -F 'TokenStore.shared.reconcileWithCurrentAuth()' "$APP_FILE" >/dev/null; then
  echo "FAIL: app launch does not reconcile auth.json into the account pool"
  exit 1
fi

if ! rg -n -F 'store.reconcileWithCurrentAuth()' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: ContentView reauth flow does not reconcile auth.json after success"
  exit 1
fi

if ! rg -n -F 'store.reconcileWithCurrentAuth()' "$MENU_FILE" >/dev/null; then
  echo "FAIL: MenuBarView reauth flow does not reconcile auth.json after success"
  exit 1
fi

echo "PASS: auth reconcile and reauth state recovery hooks are present"
