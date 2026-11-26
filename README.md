# Stack Claude

Two hotkeys that line up every Claude desktop window on your Mac: one for a vertical monitor, one for your laptop screen.

![⌃⌥⌘S stacks Claude windows on a vertical monitor; ⌃⌥⌘P tiles them on a laptop screen](docs/layouts.svg)

| Hotkey | Where | What it does |
|---|---|---|
| **⌃⌥⌘S** | Vertical monitor | Stacks every Claude window top to bottom, full width, adding a column once they would get too short |
| **⌃⌥⌘P** | Laptop screen | Side by side: 3 across, a 2×2 grid at 4 windows, 3 across in 2 rows at 5 or 6, wider rows after that |

⌃⌥⌘ is Control + Option + Command, held together.

- **Same order every time.** Oldest window first, so each chat stays in its spot.
- **Never squashed.** Claude won't let a window get shorter than 320px, so once windows would go below that, it adds a column instead.
- **No vertical monitor plugged in?** ⌃⌥⌘S tiles them on your main screen instead.
- **Minimised windows come back** and take their place.

## Install

You need [Hammerspoon](https://www.hammerspoon.org), a free, open-source Mac app that runs small scripts like this one.

1. Install Hammerspoon and open it:

   ```
   brew install --cask hammerspoon
   open -a Hammerspoon
   ```

   It asks for Accessibility access the first time. Switch it on in **System Settings > Privacy & Security > Accessibility** (it only appears in that list after this first launch).

2. Get Stack Claude and see what the installer will change:

   ```
   git clone https://github.com/statar95/stack-claude.git ~/stack-claude
   ~/stack-claude/install.sh
   ```

3. Install it:

   ```
   ~/stack-claude/install.sh --execute
   ```

Open a few Claude windows and press ⌃⌥⌘P.

The installer quits and reopens Hammerspoon so it picks up the change. It adds one line to `~/.hammerspoon/init.lua` and links the scripts from this folder, so `git pull` brings in updates. Running it again changes nothing.

## Change the keys or spacing

Edit the line the installer added to `~/.hammerspoon/init.lua`, then choose **Reload Config** from the Hammerspoon menu bar icon:

```lua
stackClaude = require("stack-claude").start({ stackKey = "m", laptopKey = "l", gap = 10 })
```

| Option | Default | |
|---|---|---|
| `mods` | `{ "ctrl", "alt", "cmd" }` | Modifier keys for both hotkeys |
| `stackKey` | `"s"` | Monitor layout |
| `laptopKey` | `"p"` | Laptop layout |
| `gap` | `6` | Pixels between windows |
| `maxColumns` | `3` | Windows per row in the laptop layout before it adds a row. A laptop fits 2 rows, so past 6 windows the rows get wider anyway |
| `minHeight` | `320` | Shortest a window gets before a column is added. Claude refuses to go below 320 |
| `app` | `"Claude"` | The app whose windows it arranges |

## Extras

The installer links two more scripts. Each is off until you add its line to `~/.hammerspoon/init.lua` and reload Hammerspoon.

**An orange border on chats waiting for you.** When Claude finishes writing in a window you're not looking at, that window gets an orange border, which clears when you click into it. It checks every 2 seconds.

```lua
stackClaudeBorder = require("stack-claude-border").start()
```

It only reads the labels of buttons in each window, to spot Claude's Stop button; it never reads your messages. To do that it asks Claude to turn on its full accessibility tree, which can make very long chats a little slower.

⌃⌥⌘0 writes a diagnostic to `~/.hammerspoon/stack-claude-border.log`: each window's title (your chat name) and the button it found. It writes nothing else to disk unless you start it with `{ log = true }`, which adds a running log of when each chat starts and finishes, by title, to `~/.hammerspoon/stack-claude-border-events.log`. If you keep `~/.hammerspoon` in a dotfiles repo, add both files to its `.gitignore`.

Options: `color`, `width`, `interval` (seconds), `mods`, `diagnosticKey`, `log`.

**Grids on Claude's own desktop.** Give Claude a desktop of its own (on that desktop, right-click Claude in the Dock > Options > Assign To > This Desktop), and these switch to it and tile the windows, in alphabetical order of chat title:

| Hotkey | Layout |
|---|---|
| **⌃⌥⌘2** | 2×2 |
| **⌃⌥⌘3** | Laptop focus: your six most recent pop-out chats fill the screen (3×2, smaller grid if fewer), the main window and any extra chats go to the Dock, other apps are hidden (on every desktop and screen; ⌘Tab or the Dock brings one back) |
| **⌃⌥⌘4** | 2×4 on a vertical monitor |

A window that can't shrink to one square, usually the main window, gets two squares and goes first. With more windows than squares, the grid grows.

```lua
stackClaudeGrid = require("stack-claude-grid").start()
```

Options: `mods`, `gridKey`, `popOutKey`, `verticalKey`, `gap`, `focusLimit` (default 6), `hideOthers` (default true).

## Why Hammerspoon

Moving another app's windows needs macOS's Accessibility permission. The first version of this was a Quick Action that launched a small app, and macOS ties that permission to the app's exact build, so every update quietly revoked it. Hammerspoon holds the permission once, and the script runs inside it.

## Troubleshooting

**Claude isn't running, or has no windows.** You'll see a short "No Claude windows open" message, and nothing moves.

**Nothing happens.** Check Hammerspoon is running (it has a menu bar icon) and is switched on in Accessibility. Its **Console** in the menu bar menu shows any errors.

**Another app or script uses one of these hotkeys.** Hammerspoon quietly lets the last one loaded win. Pick different keys with the options above.

**One window overlaps its neighbour.** The main Claude window, the one with the sidebar, won't go narrower than about 600px. Pop-out chat windows have no such limit. So whenever the columns are narrower than that (3 or more across on a laptop, 2 columns on a vertical monitor), the main window spills 100px or so into the next one. Close the main window and work in pop-outs, or keep fewer windows open.

## Uninstall

Delete the `require("stack-claude...")` lines from `~/.hammerspoon/init.lua`, then:

```
rm ~/.hammerspoon/stack-claude.lua ~/.hammerspoon/stack-claude-border.lua ~/.hammerspoon/stack-claude-grid.lua
rm -f ~/.hammerspoon/stack-claude-border.log ~/.hammerspoon/stack-claude-border-events.log
```

and reload Hammerspoon.
