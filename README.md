# Stack Claude

One hotkey that stacks all your Claude desktop windows top to bottom, full width. Built for a vertical monitor, works on any screen.

**⌃⌥⌘S** (Control + Option + Command + S) from any app.

## Install

```
git clone https://github.com/statar95/stack-claude.git
cd stack-claude
./install.sh
```

Then do the one step a script can't do for you: macOS opens Privacy & Security > Accessibility plus a Finder window with StackClaude.app selected. Drag the app into the list and switch it on.

If you have a portrait monitor it uses that. Otherwise it uses your main screen.

## How it works

- `stack-claude.js` - the script. Finds Claude's windows via System Events and resizes them into equal slices.
- `StackClaude.app` - the script compiled into a tiny background app on your Mac. It exists so you grant Accessibility to one app, rather than to every app you might press the hotkey in.
- `Stack Claude.workflow` - a Quick Action that opens the app. macOS binds the hotkey to it.

## Troubleshooting

**"StackClaude is not allowed assistive access"** - toggling the switch on isn't always enough. Remove StackClaude from the Accessibility list with **-**, drag it back in, switch it on.

**Hotkey does nothing** - log out and back in. Some apps only pick up new Quick Action hotkeys at launch. Or change the key combo in System Settings > Keyboard > Keyboard Shortcuts > Services > General > Stack Claude.

**Run it without the hotkey:** `osascript -l JavaScript stack-claude.js`

## Uninstall

```
rm -rf ~/Applications/StackClaude.app "$HOME/Library/Services/Stack Claude.workflow"
tccutil reset Accessibility com.stackclaude.app
```
