'use strict';
// Runs only on the site whose buttons were picked. A press of the start button
// tells Clockin to clock in, a press of the stop button to clock out.
(async () => {
  if (window.__clockinWatch) return;
  window.__clockinWatch = true;
  const { setup } = await chrome.storage.local.get('setup');
  if (!setup || setup.origin !== location.origin) return;

  const CLICKABLE = 'button, a, [role="button"], input[type="button"], input[type="submit"]';
  const norm = (text) => (text || '').trim().replace(/\s+/g, ' ').toLowerCase();
  const textOf = (el) => norm(el.innerText || el.value || el.getAttribute('aria-label'));
  const matches = (el, pick) => {
    if (!pick) return false;
    try { if (pick.selector && el.matches(pick.selector)) return true; } catch (_) {}
    return !!pick.text && el.tagName.toLowerCase() === pick.tag && textOf(el) === norm(pick.text);
  };

  let last = { action: null, at: 0 };
  function send(action) {
    const now = Date.now();
    if (last.action === action && now - last.at < 3000) return;
    last = { action, at: now };
    // Also announced on the page, which lets the extension's checks see it.
    document.dispatchEvent(new CustomEvent('clockin:command', { detail: action }));
    // Opening the link hands it to macOS, which passes it to Clockin. Chrome
    // asks once; "Always allow" keeps it quiet from then on.
    setTimeout(() => { window.location.href = 'clockin://' + action; }, 0);
  }

  document.addEventListener('click', (event) => {
    const el = event.target instanceof Element ? event.target.closest(CLICKABLE) : null;
    if (!el) return;
    if (setup.same) {
      // One button that changes its label: its start label means "clock in".
      if (matches(el, setup.start)) send(textOf(el) === norm(setup.start.text) ? 'clock-in' : 'clock-out');
    } else if (matches(el, setup.start)) {
      send('clock-in');
    } else if (matches(el, setup.stop)) {
      send('clock-out');
    }
  }, true);
})();
