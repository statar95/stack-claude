-- Hammerspoon version of Stack Claude. Hammerspoon already holds Accessibility,
-- so there's no separate app to grant (and no re-grant after every edit).
--   Ctrl+Option+Command+S  stack Claude windows top to bottom on a portrait monitor (else main screen)
--   Ctrl+Option+Command+P  tile them side by side on the built-in screen, up to 3 across

local M = {}

local GAP = 6
local HYPER = { "ctrl", "alt", "cmd" }

-- Equal cells; in laptop mode at most 3 across, and a short last row stretches to fill.
local function cells(n, f, laptop)
  local out = {}
  if not laptop then
    local h = math.floor((f.h - GAP * (n - 1)) / n)
    for i = 0, n - 1 do out[#out + 1] = { x = f.x, y = f.y + i * (h + GAP), w = f.w, h = h } end
    return out
  end
  local rows = math.ceil(n / 3)
  local cols = math.ceil(n / rows)
  local h = math.floor((f.h - GAP * (rows - 1)) / rows)
  for i = 0, n - 1 do
    local row = i // cols
    local inRow = math.min(cols, n - row * cols)
    local w = math.floor((f.w - GAP * (inRow - 1)) / inRow)
    out[#out + 1] = { x = f.x + (i % cols) * (w + GAP), y = f.y + row * (h + GAP), w = w, h = h }
  end
  return out
end

local function targetScreen(laptop)
  for _, s in ipairs(hs.screen.allScreens()) do
    local f = s:fullFrame()
    if laptop and (s:name() or ""):find("Built%-in") then return s end
    if not laptop and f.h > f.w then return s end
  end
  return hs.screen.primaryScreen()
end

function M.arrange(laptop)
  local app = hs.application.get("Claude")
  if not app then hs.alert.show("Claude is not running") return end
  local wins = {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then wins[#wins + 1] = w end
  end
  if #wins == 0 then hs.alert.show("No Claude windows open") return end

  local layout = cells(#wins, targetScreen(laptop):frame(), laptop)
  for i, w in ipairs(wins) do
    if w:isMinimized() then w:unminimize() end
    w:setFrame(layout[i], 0)
    w:raise()
  end
end

M.stackHotkey = hs.hotkey.bind(HYPER, "s", function() M.arrange(false) end)
M.laptopHotkey = hs.hotkey.bind(HYPER, "p", function() M.arrange(true) end)

return M
