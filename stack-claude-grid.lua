-- Stack Claude grids: tile Claude windows into a grid on Claude's own desktop.
--   Ctrl+Option+Command+2  2x2
--   Ctrl+Option+Command+3  3x3, pop-out chats only: the main window (the one with the sidebar) goes to the Dock
--   Ctrl+Option+Command+4  2x4 on a vertical monitor: two across, four down
-- Windows go in alphabetical order of chat title. A window that can't shrink to one square (usually the
-- main window) gets two squares, placed first. More windows than squares and the grid grows to fit.
-- To give Claude its own desktop: on that desktop, right-click Claude in the Dock > Options > Assign To > This Desktop.

local M = {}

local defaults = {
  app = "Claude",
  mods = { "ctrl", "alt", "cmd" },
  gap = 6,
  gridKey = "2",
  popOutKey = "3",
  verticalKey = "4",
}

local TOLERANCE = 20 -- px a window may overshoot its square before it counts as wide
local config = {}

local function plan(f, wins, spans, cols, rows, growRows)
  local gap = config.gap
  while true do
    local cellW = (f.w - gap * (cols - 1)) / cols
    local cellH = (f.h - gap * (rows - 1)) / rows
    local rects, col, row = {}, 0, 0
    for i = 1, #wins do
      local s = math.min(spans[i], cols)
      if col + s > cols then col, row = 0, row + 1 end
      rects[i] = {
        x = f.x + col * (cellW + gap),
        y = f.y + row * (cellH + gap),
        w = s * cellW + (s - 1) * gap,
        h = cellH,
      }
      col = col + s
      if col >= cols then col, row = 0, row + 1 end
    end
    local usedRows = (col == 0) and row or row + 1
    if usedRows <= rows then return rects, cellW end
    if growRows or cols > rows then rows = rows + 1 else cols = cols + 1 end
  end
end

-- macOS can clamp a window's size on the first move, so move, resize, then set the frame again.
local function apply(wins, rects)
  local animation = hs.window.animationDuration
  hs.window.animationDuration = 0
  local ok, err = pcall(function()
    for i, w in ipairs(wins) do
      local r = rects[i]
      w:setTopLeft({ x = r.x, y = r.y })
      w:setSize({ w = r.w, h = r.h })
      w:setFrame(r, 0)
    end
  end)
  hs.window.animationDuration = animation
  if not ok then error(err, 0) end
end

local function isMain(w)
  local t = (w:title() or ""):lower()
  return t == "" or t == config.app:lower()
end

local function verticalScreen()
  for _, sc in ipairs(hs.screen.allScreens()) do
    local fr = sc:fullFrame()
    if fr.h > fr.w then return sc end
  end
end

function M.tile(cols, rows, pickScreen, popOutsOnly)
  local app = hs.application.get(config.app)
  if not app then hs.alert.show(config.app .. " isn't running") return end

  app:activate(true)

  -- Wait for the switch to Claude's desktop to finish before measuring anything.
  hs.timer.doAfter(0.7, function()
    local mainWin = nil
    if popOutsOnly then
      local std, mains = 0, {}
      for _, w in ipairs(app:allWindows()) do
        if w:isStandard() then
          std = std + 1
          if isMain(w) then table.insert(mains, w) end
        end
      end
      if #mains == 1 and std > 1 then mainWin = mains[1] end
    end
    local minimisedOne = mainWin ~= nil

    local wins = {}
    for _, w in ipairs(app:allWindows()) do
      if mainWin and w:id() == mainWin:id() then
        if not w:isMinimized() then w:minimize() end
      elseif w:isStandard() then
        if w:isMinimized() then w:unminimize() end
        if w:isFullScreen() then w:setFullScreen(false) end
        table.insert(wins, w)
      end
    end
    if #wins == 0 then hs.alert.show("No Claude windows open") return end

    local screen = wins[1]:screen() or hs.screen.mainScreen()
    if pickScreen then
      screen = pickScreen()
      if not screen then hs.alert.show("No vertical monitor plugged in") return end
    end
    local f = screen:frame()

    local function sortWins(spans)
      local idx = {}
      for i = 1, #wins do idx[i] = i end
      table.sort(idx, function(a, b)
        local sa, sb = spans[wins[a]:id()] or 1, spans[wins[b]:id()] or 1
        if sa ~= sb then return sa > sb end
        local ta, tb = (wins[a]:title() or ""):lower(), (wins[b]:title() or ""):lower()
        if ta == tb then return wins[a]:id() < wins[b]:id() end
        return ta < tb
      end)
      local sorted, s = {}, {}
      for k, i in ipairs(idx) do sorted[k] = wins[i]; s[k] = spans[wins[i]:id()] or 1 end
      return sorted, s
    end

    local spanById = {}
    local ordered, spans = sortWins(spanById)
    local rects, cellW = plan(f, ordered, spans, cols, rows, pickScreen ~= nil)
    apply(ordered, rects)

    -- Some windows only settle on a second pass; any still too wide after that can't shrink to one square.
    hs.timer.doAfter(0.25, function()
      apply(ordered, rects)

      hs.timer.doAfter(0.35, function()
        local changed = false
        local kept, widest = {}, nil
        if popOutsOnly and not minimisedOne then
          for _, w in ipairs(ordered) do
            if w:frame().w > cellW + TOLERANCE and (not widest or w:frame().w > widest:frame().w) then widest = w end
          end
          if widest and #ordered < 2 then widest = nil end
        end
        for _, w in ipairs(ordered) do
          if widest and w:id() == widest:id() then
            w:minimize()
            minimisedOne = true
            changed = true
          elseif w:frame().w > cellW + TOLERANCE and not spanById[w:id()] then
            spanById[w:id()] = 2
            table.insert(kept, w)
            changed = true
          else
            table.insert(kept, w)
          end
        end
        if changed then
          wins = kept
          ordered, spans = sortWins(spanById)
          rects = plan(f, ordered, spans, cols, rows, pickScreen ~= nil)
          apply(ordered, rects)
          hs.timer.doAfter(0.25, function() apply(ordered, rects) end)
        end
        local n = #ordered
        hs.alert.show("Tiled " .. n .. " Claude window" .. (n > 1 and "s" or ""))
      end)
    end)
  end)
end

function M.start(options)
  for k, v in pairs(defaults) do config[k] = v end
  for k, v in pairs(options or {}) do config[k] = v end
  if M.hotkeys then
    for _, h in ipairs(M.hotkeys) do h:delete() end
  end
  M.hotkeys = {
    hs.hotkey.bind(config.mods, config.gridKey, function() M.tile(2, 2) end),
    hs.hotkey.bind(config.mods, config.popOutKey, function() M.tile(3, 3, nil, true) end),
    hs.hotkey.bind(config.mods, config.verticalKey, function() M.tile(2, 4, verticalScreen) end),
  }
  return M
end

return M
