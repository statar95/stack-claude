-- Stack Claude border: an orange border on any Claude chat window that has finished and is waiting on you.
-- A window counts as finished when it had a Stop button (Claude writing) and now doesn't.
-- The border clears when you click into that window. Ctrl+Option+Command+0 writes a diagnostic
-- to ~/.hammerspoon/stack-claude-border.log. Writes nothing else unless you start it with { log = true }.

local M = { state = {}, canvases = {} }

local defaults = {
  app = "Claude",
  interval = 2,
  color = { red = 1, green = 0.55, blue = 0, alpha = 0.95 },
  width = 5,
  mods = { "ctrl", "alt", "cmd" },
  diagnosticKey = "0",
  log = false,
}

local MAX_NODES = 3000
local DIAGNOSTIC = os.getenv("HOME") .. "/.hammerspoon/stack-claude-border.log"
local EVENTS = os.getenv("HOME") .. "/.hammerspoon/stack-claude-border-events.log"

local config = {}

local function event(msg)
  if not config.log then return end
  local f = io.open(EVENTS, "a")
  if f then f:write(os.date("%Y-%m-%d %H:%M:%S ") .. msg .. "\n"); f:close() end
end

local function claudeApp() return hs.application.get(config.app) end

local function label(el)
  local t = el:attributeValue("AXTitle") or ""
  local d = el:attributeValue("AXDescription") or ""
  return (t .. " " .. d):lower()
end

-- The composer's Send/Stop button is at the bottom of the window, so walking the tree last child first
-- finds it in ~60 elements. Walking top down crawls the whole chat and stalls Hammerspoon on long ones.
local function composerButton(win)
  local root = hs.axuielement.windowElement(win)
  if not root then return nil, 0 end
  local stack, n = { root }, 0
  while #stack > 0 and n < MAX_NODES do
    local el = table.remove(stack); n = n + 1
    if el:attributeValue("AXRole") == "AXButton" then
      local l = label(el)
      if l:match("stop") or l:match("send") then return l, n end
    end
    local kids = el:attributeValue("AXChildren") or {}
    for i = 1, #kids do stack[#stack + 1] = kids[i] end
  end
  return nil, n
end

local function isWriting(win)
  local l = composerButton(win)
  return l ~= nil and l:match("stop") ~= nil
end

local function drawBorder(win)
  local id, f = win:id(), win:frame()
  local c = M.canvases[id]
  if not c then
    c = hs.canvas.new(f)
    c:level(hs.canvas.windowLevels.floating)
    c:clickActivating(false)
    c[1] = { type = "rectangle", action = "stroke", strokeColor = config.color, strokeWidth = config.width,
             roundedRectRadii = { xRadius = 10, yRadius = 10 } }
    M.canvases[id] = c
  end
  c:frame(f)
  c:show()
end

local function clearBorder(id)
  if M.canvases[id] then M.canvases[id]:delete(); M.canvases[id] = nil end
end

local function clearAll()
  for id in pairs(M.canvases) do clearBorder(id) end
end

-- Electron apps such as Claude only expose their contents to accessibility once asked, and forget on restart.
local function enableAccessibility()
  local app = claudeApp()
  if app then
    pcall(function() hs.axuielement.applicationElement(app):setAttributeValue("AXManualAccessibility", true) end)
    M.pid = app:pid()
  end
end

local function tick()
  local app = claudeApp()
  if not app then clearAll(); return end
  if app:pid() ~= M.pid then enableAccessibility() end
  local focused = hs.window.focusedWindow()
  local seen = {}
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() then
      local id = w:id()
      seen[id] = true
      local st = M.state[id] or { writing = false, waiting = false }
      M.state[id] = st
      if focused and focused:id() == id then
        st.waiting = false
        st.writing = isWriting(w)
      elseif not w:isMinimized() then
        local writing = isWriting(w)
        if writing ~= st.writing then event((writing and "WRITING  " or "FINISHED ") .. (w:title() or "?")) end
        if st.writing and not writing then st.waiting = true end
        st.writing = writing
      end
      if st.waiting and w:isVisible() then
        local ok, err = pcall(drawBorder, w)
        if not ok then event("DRAW ERROR " .. tostring(err))
        elseif not st.drawn then event("BORDER ON " .. (w:title() or "?")); st.drawn = true end
      else
        if st.drawn then event("BORDER OFF " .. (w:title() or "?")); st.drawn = false end
        clearBorder(id)
      end
    end
  end
  for id in pairs(M.state) do if not seen[id] then M.state[id] = nil; clearBorder(id) end end
end

function M.diagnostic()
  enableAccessibility()
  local app = claudeApp()
  local out = { os.date() .. "  running=" .. tostring(M.timer ~= nil and M.timer:running()) }
  if app and #app:allWindows() == 0 then
    table.insert(out, "No " .. config.app .. " windows on this desktop. Run it again from the desktop they're on.")
  elseif app then
    for _, w in ipairs(app:allWindows()) do
      local t0 = hs.timer.secondsSinceEpoch()
      local l, n = composerButton(w)
      local ms = math.floor((hs.timer.secondsSinceEpoch() - t0) * 1000)
      table.insert(out, string.format("== %s | nodes=%d | %dms | composer button: %s",
        w:title() or "?", n or 0, ms, l or "NOT FOUND"))
    end
  else
    table.insert(out, config.app .. " not running")
  end
  local f = assert(io.open(DIAGNOSTIC, "w"))
  f:write(table.concat(out, "\n") .. "\n")
  f:close()
  return table.concat(out, "\n")
end

function M.start(options)
  for k, v in pairs(defaults) do config[k] = v end
  for k, v in pairs(options or {}) do config[k] = v end
  M.stop()
  enableAccessibility()
  M.timer = hs.timer.new(config.interval, function()
    local ok, err = pcall(tick)
    if not ok then event("ERROR " .. tostring(err)) end
  end)
  M.timer:start()
  M.focusWatch = hs.window.filter.new(config.app):subscribe(hs.window.filter.windowFocused, function(w)
    if w and M.state[w:id()] then
      M.state[w:id()].waiting = false
      M.state[w:id()].drawn = false
      clearBorder(w:id())
    end
  end)
  M.hotkey = hs.hotkey.bind(config.mods, config.diagnosticKey, function()
    M.diagnostic()
    hs.alert.show("Stack Claude border diagnostic written")
  end)
  event("STARTED")
  return M
end

function M.stop()
  if M.timer then M.timer:stop(); M.timer = nil end
  if M.focusWatch then M.focusWatch:unsubscribeAll(); M.focusWatch = nil end
  if M.hotkey then M.hotkey:delete(); M.hotkey = nil end
  clearAll()
  M.state = {}
end

return M
