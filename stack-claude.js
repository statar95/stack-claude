#!/usr/bin/osascript -l JavaScript
// Stack all open Claude desktop windows top to bottom.
// Uses a vertical (portrait) monitor if you have one, otherwise your main screen.
ObjC.import('AppKit');

const APP_NAME = 'Claude';
const GAP = 6;

function notify(msg) {
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  app.displayNotification(msg, { withTitle: 'Stack Claude' });
}

function run() {
  const screens = $.NSScreen.screens.js;
  const primaryHeight = screens[0].frame.size.height;
  const target = screens.find(s => s.frame.size.height > s.frame.size.width) || screens[0];

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

  const n = wins.length;
  const sliceHeight = Math.floor((height - GAP * (n - 1)) / n);

  wins.forEach((w, i) => {
    try {
      const minimized = w.attributes.byName('AXMinimized');
      if (minimized.value()) minimized.value = false;
    } catch (e) {}
    const y = Math.round(top + i * (sliceHeight + GAP));
    // Position, size, position again: a window can refuse a size that would push it off-screen.
    w.position = [Math.round(left), y];
    w.size = [Math.round(width), sliceHeight];
    w.position = [Math.round(left), y];
    try { w.actions.byName('AXRaise').perform(); } catch (e) {}
  });
}
