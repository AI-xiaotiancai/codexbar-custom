#!/bin/sh

set -eu

CONTENT_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/ContentView.swift"
MENU_FILE="/Users/chenqianying/Desktop/develop/codexbar/codexBar/Views/MenuBarView.swift"

if ! rg -n 'settings\.showDockIcon|Toggle\(isOn:' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: ContentView is missing display mode settings UI"
  exit 1
fi

if ! rg -n 'groupedAccounts|AccountRowView|L\.accountOverview' "$CONTENT_FILE" >/dev/null; then
  echo "FAIL: ContentView is missing account overview"
  exit 1
fi

if ! rg -n 'openWindow|settings\.toggleDockIcon' "$MENU_FILE" >/dev/null; then
  echo "FAIL: MenuBarView is missing main window entry"
  exit 1
fi

echo "PASS: main window and menu entry are present"
