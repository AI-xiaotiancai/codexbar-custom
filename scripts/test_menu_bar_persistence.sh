#!/bin/bash
set -euo pipefail

APP_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/codexBarApp.swift"
CONTROLLER_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Services/MenuBarStatusController.swift"
CONTENT_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/ContentView.swift"
L10N_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Localization.swift"

if [[ ! -f "$APP_FILE" || ! -f "$CONTROLLER_FILE" || ! -f "$CONTENT_FILE" || ! -f "$L10N_FILE" ]]; then
  echo "FAIL: required source files are missing"
  exit 1
fi

if ! rg -n 'MenuBarStatusController\.shared\.install\(\)' "$APP_FILE" >/dev/null; then
  echo "FAIL: app does not install the AppKit status item controller"
  exit 1
fi

if ! rg -n 'NSApplicationDelegateAdaptor' "$APP_FILE" >/dev/null; then
  echo "FAIL: app does not use an application delegate to install the status item after launch"
  exit 1
fi

if ! rg -n 'NSStatusBar\.system\.statusItem' "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: menu bar controller does not create a persistent NSStatusItem"
  exit 1
fi

if ! rg -n 'NSPopover' "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: menu bar controller does not host the menu content in a popover"
  exit 1
fi

if ! rg -n 'MenuBarView\(\)' "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: menu bar controller does not embed the SwiftUI menu view"
  exit 1
fi

if ! rg -n 'ensureStatusItem\(\)|applicationDidFinishLaunching|applicationDidBecomeActive|didBecomeActiveNotification' "$CONTROLLER_FILE" "$APP_FILE" >/dev/null; then
  echo "FAIL: menu bar controller lacks launch/reactivation recovery hooks"
  exit 1
fi

if ! rg -n 'scheduleRecoveryChecks\(\)|let delays: \[TimeInterval\] = \[0\.5, 1\.5\]' "$APP_FILE" "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: app does not schedule delayed status item recovery after launch"
  exit 1
fi

if ! rg -n 'restoreMenuBarIcon|恢复菜单栏图标' "$CONTENT_FILE" "$L10N_FILE" "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: main window does not provide a restore menu bar icon action"
  exit 1
fi

if ! rg -n 'restoreIfNeededFromMainWindow\(\)|mainWindow != nil \|\| keyWindow != nil' "$CONTENT_FILE" "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: main window does not auto-restore a missing menu bar item when visible"
  exit 1
fi

if ! rg -n 'handleAccountsChanged\(\)|lastActiveAccountId|self\?\.handleAccountsChanged\(\)' "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: menu bar controller does not recover when the active account changes"
  exit 1
fi

if ! rg -n 'restoreStatusItem\(|removeStatusItem\(|button\?\.window == nil' "$CONTROLLER_FILE" "$CONTENT_FILE" "$APP_FILE" >/dev/null; then
  echo "FAIL: menu bar controller cannot force-rebuild an invalid status item"
  exit 1
fi

if ! rg -n 'schedulePeriodicHealthChecks\(\)|healthCheckTimer|scheduledTimer\(withTimeInterval:' "$CONTROLLER_FILE" >/dev/null; then
  echo "FAIL: menu bar controller does not run periodic health checks for the status item"
  exit 1
fi

echo "PASS: menu bar persistence uses a dedicated AppKit status item controller"
