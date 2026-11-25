-- Stack Claude: two hotkeys that line up every Claude desktop window.
--   Ctrl+Option+Command+S  monitor: stack them top to bottom on a vertical monitor
--   Ctrl+Option+Command+P  laptop: tile them side by side on the built-in screen
-- Windows land in the same order every time, oldest first. Pressing a key twice changes nothing.

local M = {}

local defaults = {
  app = "Claude",
  mods = { "ctrl", "alt", "cmd" },
  stackKey = "s",
  laptopKey = "p",
  gap = 6,
  maxColumns = 3,
  -- Claude refuses to make a window shorter than this, so layouts never go below it.
  minHeight = 320,
}

local config = {}

local function claudeWindows()
  local app = hs.application.get(config.app)
  if not app then return {} end
  local wins = {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then wins[#wins + 1] = w end
  end
  table.sort(wins, function(a, b) return a:id() < b:id() end)
  return wins
end

local function rowsThatFit(frame)
  return math.max(1, math.floor((frame.h + config.gap) / (config.minHeight + config.gap)))
end

local function cells(n, frame, cols)
  local gap = config.gap
  local rows = math.ceil(n / cols)
  local h = math.floor((frame.h - gap * (rows - 1)) / rows)
  local out = {}
  for i = 0, n - 1 do
    local row = i // cols
    local inRow = math.min(cols, n - row * cols)
    local w = math.floor((frame.w - gap * (inRow - 1)) / inRow)
    out[#out + 1] = {
      x = frame.x + (i % cols) * (w + gap),
      y = frame.y + row * (h + gap),
      w = w,
      h = h,
    }
  end
  return out
end

local function stackColumns(n, frame)
  return math.ceil(n / rowsThatFit(frame))
end

local function tileColumns(n, frame)
  local rows = math.min(math.ceil(n / config.maxColumns), rowsThatFit(frame))
  return math.ceil(n / rows)
end

local function verticalScreen()
  for _, s in ipairs(hs.screen.allScreens()) do
    local f = s:fullFrame()
    if f.h > f.w then return s end
  end
end

local function laptopScreen()
  for _, s in ipairs(hs.screen.allScreens()) do
    if (s:name() or ""):find("Built%-in") then return s end
  end
  return hs.screen.primaryScreen()
end

local function arrange(screen, columnsFor, label)
  local wins = claudeWindows()
  if #wins == 0 then
    hs.alert.show("No Claude windows open")
    return
  end
  local frame = screen:frame()
  local layout = cells(#wins, frame, columnsFor(#wins, frame))
  for i, w in ipairs(wins) do
    if w:isMinimized() then w:unminimize() end
    w:setFrame(layout[i], 0)
    w:raise()
  end
  hs.alert.show(string.format("%d Claude windows %s", #wins, label), 0.8)
end

function M.stack()
  local screen = verticalScreen()
  if screen then
    arrange(screen, stackColumns, "stacked")
  else
    arrange(hs.screen.primaryScreen(), tileColumns, "tiled (no vertical monitor)")
  end
end

function M.laptop()
  arrange(laptopScreen(), tileColumns, "tiled")
end

function M.start(options)
  for k, v in pairs(defaults) do config[k] = v end
  for k, v in pairs(options or {}) do config[k] = v end
  if M.hotkeys then
    for _, h in ipairs(M.hotkeys) do h:delete() end
  end
  M.hotkeys = {
    hs.hotkey.bind(config.mods, config.stackKey, M.stack),
    hs.hotkey.bind(config.mods, config.laptopKey, M.laptop),
  }
  return M
end

return M
