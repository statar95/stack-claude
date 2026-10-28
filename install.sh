#!/bin/zsh
# Installs Stack Claude: a Ctrl+Option+Command+S hotkey that stacks your Claude desktop windows.
# Everything is built on your own Mac from source, nothing pre-compiled is downloaded.
set -euo pipefail

HERE="${0:A:h}"
APP="$HOME/Applications/StackClaude.app"
SERVICE="$HOME/Library/Services/Stack Claude.workflow"
BUNDLE_ID="com.stackclaude.app"

echo "1/4  Building StackClaude.app"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -l JavaScript -o "$APP" "$HERE/stack-claude.js"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" 2>/dev/null
# A rebuilt app has a new signature, so any old Accessibility grant no longer matches it.
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "2/4  Installing the Quick Action"
mkdir -p "$HOME/Library/Services"
rm -rf "$SERVICE"
cp -R "$HERE/Stack Claude.workflow" "$SERVICE"

echo "3/4  Binding Ctrl+Option+Command+S"
defaults write pbs NSServicesStatus -dict-add '"(null) - Stack Claude - runWorkflowAsService"' \
  '{ "key_equivalent" = "@~^s"; "enabled_context_menu" = 1; "enabled_services_menu" = 1; "presentation_modes" = { "ContextMenu" = 1; "ServicesMenu" = 1; }; }'
/System/Library/CoreServices/pbs -update

echo "4/4  One manual step: allow it in Accessibility"
if [[ -z "${STACK_CLAUDE_NO_OPEN:-}" ]]; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  open -R "$APP"
fi
cat <<'EOF'

    Drag StackClaude.app from the Finder window into the Accessibility list
    and switch it on. (If StackClaude is already listed, remove it with - first.)

    Then press Ctrl+Option+Command+S in any app.
EOF
