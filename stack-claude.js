#!/usr/bin/osascript -l JavaScript
// Stack all open Claude desktop windows top to bottom.
// Uses a vertical (portrait) monitor if you have one, otherwise your main screen.
// Pass `laptop` to tile them side by side on the built-in screen instead (2+ rows once there are 4+).
ObjC.import('AppKit');

const APP_NAME = 'Claude';
const GAP = 6;

function notify(msg) {
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  app.displayNotification(msg, { withTitle: 'Stack Claude' });
}

// Arguments arrive via `open --args`; a compiled app's run() doesn't get them.
function wantsLaptop() {
  return ObjC.deepUnwrap($.NSProcessInfo.processInfo.arguments).includes('laptop');
}

// Equal cells, at most 3 across; the last row stretches to fill if it's short.
function cells(n, left, top, width, height, laptop) {
  if (!laptop) {
    const h = Math.floor((height - GAP * (n - 1)) / n);
    return [...Array(n)].map((_, i) => [left, top + i * (h + GAP), width, h]);
  }
  const rows = Math.ceil(n / 3);
  const cols = Math.ceil(n / rows);
  const h = Math.floor((height - GAP * (rows - 1)) / rows);
  return [...Array(n)].map((_, i) => {
    const row = Math.floor(i / cols);
    const inRow = Math.min(cols, n - row * cols);
    const w = Math.floor((width - GAP * (inRow - 1)) / inRow);
    return [left + (i % cols) * (w + GAP), top + row * (h + GAP), w, h];
  });
}

function run() {
  const laptop = wantsLaptop();
  const screens = $.NSScreen.screens.js;
  const primaryHeight = screens[0].frame.size.height;
  const target = laptop
    ? screens.find(s => s.localizedName.js.includes('Built-in')) || screens[0]
    : screens.find(s => s.frame.size.height > s.frame.size.width) || screens[0];

  // Cocoa measures y from the bottom of the primary screen, window positions from the top.
  const vf = target.visibleFrame;
  const left = vf.origin.x;
  const top = primaryHeight - (vf.origin.y + vf.size.height);
  const width = vf.size.width;
  const height = vf.size.height;

  const se = Application('System Events');
  if (se.processes.whose({ name: APP_NAME }).length === 0) { notify('Claude is not running.'); return; }
  const proc = se.processes.byName(APP_NAME);
  const wins = proc.windows().filter(w => {
    try { return w.subrole() === 'AXStandardWindow'; } catch (e) { return false; }
  });
  if (wins.length === 0) { notify('No Claude windows open.'); return; }

  const layout = cells(wins.length, left, top, width, height, laptop);

  wins.forEach((w, i) => {
    const [x, y, cw, ch] = layout[i].map(Math.round);
    try {
      const minimized = w.attributes.byName('AXMinimized');
      if (minimized.value()) minimized.value = false;
    } catch (e) {}
    // Position, size, position again: a window can refuse a size that would push it off-screen.
    w.position = [x, y];
    w.size = [cw, ch];
    w.position = [x, y];
    try { w.actions.byName('AXRaise').perform(); } catch (e) {}
  });
}
