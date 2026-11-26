#!/bin/zsh
# Installs Stack Claude into Hammerspoon.
# Writes links in ~/.hammerspoon to the three scripts in this folder (so `git pull` updates them) and one line
# in ~/.hammerspoon/init.lua that turns on the main hotkeys, then restarts Hammerspoon. The border and grids
# stay off until you add their lines (README, Extras).
# Shows what it would change by default; add --execute to install. Running it twice changes nothing.
set -euo pipefail

HERE="${0:A:h}"
HS_DIR="$HOME/.hammerspoon"
INIT="$HS_DIR/init.lua"
MODULES=(stack-claude stack-claude-border stack-claude-grid)
LINE='stackClaude = require("stack-claude").start()'
LOADS='^[[:space:]]*[^-[:space:]].*require[[:space:](]*["'"'"']stack-claude["'"'"']'

loads_stack_claude() { [[ -f "$INIT" ]] && grep -qE "$LOADS" "$INIT"; }

EXECUTE=0
case "${1:-}" in
  "") ;;
  --execute) EXECUTE=1 ;;
  *) echo "Unknown option: $1 (run with no options to preview, or --execute to install)" >&2; exit 2 ;;
esac

if [[ ! -d /Applications/Hammerspoon.app && ! -d "$HOME/Applications/Hammerspoon.app" ]]; then
  echo "FIX: Hammerspoon isn't installed. Install it, then run this again:"
  echo "  brew install --cask hammerspoon      (or download it from https://www.hammerspoon.org)"
  exit 1
fi

todo=0
for m in $MODULES; do
  link="$HS_DIR/$m.lua"
  if [[ "$(readlink "$link" 2>/dev/null || true)" == "$HERE/$m.lua" ]]; then
    echo "ok    $link already links here"
  elif [[ -e "$link" || -L "$link" ]]; then
    echo "FIX: $link already exists and isn't this script. Move it aside, then run this again." >&2
    exit 2
  else
    echo "add   $link -> $HERE/$m.lua"; todo=1
  fi
done
if loads_stack_claude; then
  echo "ok    $INIT already loads Stack Claude"
else
  echo "add   this line to $INIT:  $LINE"; todo=1
fi

if (( ! todo )); then
  echo "Already installed. Press Ctrl+Option+Command+S (monitor) or +P (laptop)."
  exit 0
fi
echo "then  quit and reopen Hammerspoon so it loads the change"
if (( ! EXECUTE )); then
  echo
  echo "Preview only, nothing changed. To install:  $0 --execute"
  exit 0
fi

mkdir -p "$HS_DIR"
for m in $MODULES; do
  [[ -L "$HS_DIR/$m.lua" ]] || ln -s "$HERE/$m.lua" "$HS_DIR/$m.lua"
  [[ "$(readlink "$HS_DIR/$m.lua")" == "$HERE/$m.lua" ]] || { echo "FAILED: $HS_DIR/$m.lua does not point here. FIX: remove it and run this again" >&2; exit 1; }
done
if ! loads_stack_claude; then
  printf '\n%s\n' "$LINE" >> "$INIT"
fi
loads_stack_claude || { echo "FAILED: $INIT does not load Stack Claude. FIX: add this line to it: $LINE" >&2; exit 1; }

killall Hammerspoon 2>/dev/null || true
for _ in {1..50}; do pgrep -xq Hammerspoon || break; sleep 0.2; done
open -a Hammerspoon
for _ in {1..50}; do pgrep -xq Hammerspoon && break; sleep 0.2; done
pgrep -xq Hammerspoon || { echo "FAILED: Hammerspoon didn't reopen. FIX: open it yourself; Stack Claude is installed and loads when it starts" >&2; exit 1; }

cat <<'EOF'

Installed. Hammerspoon has restarted with Stack Claude loaded.

  Ctrl+Option+Command+S   stack Claude windows on your vertical monitor
  Ctrl+Option+Command+P   tile them side by side on your laptop screen

The orange "waiting on you" border and the desktop grids are off until you add their lines (README, Extras).

First time with Hammerspoon? It needs one permission: System Settings > Privacy & Security >
Accessibility, switch Hammerspoon on.
EOF
