#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OAUTH_FILE="$ROOT/codexBar/Services/OAuthManager.swift"
CONTENT_FILE="$ROOT/codexBar/ContentView.swift"
MENU_FILE="$ROOT/codexBar/Views/MenuBarView.swift"

if [[ ! -f "$OAUTH_FILE" || ! -f "$CONTENT_FILE" || ! -f "$MENU_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n '"login".*"--device-auth"|login --device-auth' "$OAUTH_FILE" >/dev/null; then
  echo "FAIL: OAuthManager is not using codex login --device-auth"
  exit 1
fi

if rg -n 'oauth/authorize|oauth/token|codex_cli_simplified_flow|id_token_add_organizations' "$OAUTH_FILE" >/dev/null; then
  echo "FAIL: OAuthManager still contains the deprecated browser OAuth flow"
  exit 1
fi

if ! rg -n -F 'FileManager.default.temporaryDirectory' "$OAUTH_FILE" >/dev/null || ! rg -n -F 'HOME' "$OAUTH_FILE" >/dev/null; then
  echo "FAIL: OAuthManager is not isolating the CLI login inside a temporary HOME"
  exit 1
fi

if ! rg -n -F 'extractDeviceAuthInstructions' "$OAUTH_FILE" >/dev/null; then
  echo "FAIL: OAuthManager does not parse device-auth instructions"
  exit 1
fi

if ! rg -n -F 'readTokens(fromAuthFile:' "$OAUTH_FILE" >/dev/null; then
  echo "FAIL: OAuthManager does not import tokens from the CLI auth.json"
  exit 1
fi

if ! rg -n -F 'if account.isActive {' "$CONTENT_FILE" >/dev/null || ! rg -n -F 'try store.activate(updated)' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: active account reauth does not re-write auth.json from ContentView"
  exit 1
fi

if ! rg -n -F 'if account.isActive {' "$MENU_FILE" >/dev/null || ! rg -n -F 'try store.activate(updated)' "$MENU_FILE" >/dev/null; then
  echo "FAIL: active account reauth does not re-write auth.json from MenuBarView"
  exit 1
fi

echo "PASS: OAuth reauth flow uses codex device auth and re-activates active accounts"
