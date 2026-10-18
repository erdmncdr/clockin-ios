'use strict';
// Runs only on the site whose buttons were picked. A press of the start button
// tells Clockin to clock in, a press of the end button to clock out.
(async () => {
  if (window.__clockinWatch) return;
  window.__clockinWatch = true;
  const { setup } = await chrome.storage.local.get('setup');
  if (!setup || setup.origin !== location.origin) return;

  const norm = (text) => (text || '').trim().replace(/\s+/g, ' ').toLowerCase();
  const textOf = (el) => norm(el.innerText || el.value || el.getAttribute('aria-label'));
  const matches = (el, pick) => {
    if (!pick) return false;
    try { if (pick.selector && el.matches(pick.selector)) return true; } catch (_) {}
    return !!pick.text && el.tagName.toLowerCase() === pick.tag && textOf(el) === norm(pick.text);
  };

  // The picked element may be the clicked one or one it sits in: sites build
  // buttons from divs and spans as often as from <button>.
  function actionFor(event) {
    for (const node of event.composedPath()) {
      if (!(node instanceof Element) || node === document.body || node === document.documentElement) continue;
      if (setup.same) {
        // One button that changes its label: its start label means "clock in".
        if (matches(node, setup.start)) return textOf(node) === norm(setup.start.text) ? 'clock-in' : 'clock-out';
      } else if (matches(node, setup.start)) {
        return 'clock-in';
      } else if (matches(node, setup.stop)) {
        return 'clock-out';
      }
    }
    return null;
  }

  let last = { action: null, at: 0 };
  function send(action) {
    const now = Date.now();
    if (last.action === action && now - last.at < 3000) return;
    last = { action, at: now };
    chrome.storage.local.set({ lastEvent: { action, at: now } });
    // Also announced on the page, which lets the extension's checks see it.
    document.dispatchEvent(new CustomEvent('clockin:command', { detail: action }));
    // A hidden frame of its own opens the link, so it neither interrupts nor is
    // cancelled by the site's own navigation after the click. Chrome asks
    // once; "Always allow" keeps it quiet from then on.
    const frame = document.createElement('iframe');
    frame.style.display = 'none';
    frame.src = 'clockin://' + action;
    document.documentElement.appendChild(frame);
    setTimeout(() => frame.remove(), 5000);
  }

  document.addEventListener('click', (event) => {
    const action = actionFor(event);
    if (action) send(action);
  }, true);
})();
