'use strict';
// Runs only on the site whose buttons were picked. A real press of the start
// button tells Clockin to clock in, of the end button to clock out.
(async () => {
  if (window.__clockinWatch) return;
  window.__clockinWatch = true;
  const { setup } = await chrome.storage.local.get('setup');
  if (!setup || setup.origin !== location.origin) return;

  const tr = (navigator.language || '').toLowerCase().startsWith('tr');
  const norm = (text) => (text || '').trim().replace(/\s+/g, ' ').toLowerCase();
  const textOf = (el) => norm(el.innerText || el.value || el.getAttribute('aria-label'));
  const present = (selector) => { try { return !!selector && !!document.querySelector(selector); } catch (_) { return false; } };
  // The picked element's position decides. Its label only stands in when the
  // site has rebuilt the page and nothing sits at that position any more, so
  // another "Clock out" elsewhere (a history row, say) never counts.
  const matches = (el, pick) => {
    if (!pick) return false;
    try { if (pick.selector && el.matches(pick.selector)) return true; } catch (_) {}
    return !present(pick.selector) && !!pick.text && el.tagName.toLowerCase() === pick.tag && textOf(el) === norm(pick.text);
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

  function toast(text, good) {
    const note = document.createElement('div');
    note.setAttribute('style', 'all:initial;position:fixed;z-index:2147483647;right:16px;bottom:16px;padding:9px 13px;border-radius:10px;' +
      `background:${good ? '#14532d' : '#7c2d12'};color:#fff;font:600 13px -apple-system,BlinkMacSystemFont,sans-serif;` +
      'box-shadow:0 8px 24px rgba(0,0,0,.3)');
    note.textContent = text;
    document.documentElement.appendChild(note);
    setTimeout(() => note.remove(), 3000);
  }

  // Older Clockin builds have no native host: hand them a clockin:// link from a
  // hidden frame, which a navigation right after the click cannot cancel.
  function openLink(action) {
    const frame = document.createElement('iframe');
    frame.style.display = 'none';
    frame.src = 'clockin://' + action;
    document.documentElement.appendChild(frame);
    setTimeout(() => frame.remove(), 5000);
  }

  let last = { action: null, at: 0 };
  function send(action) {
    const now = Date.now();
    if (last.action === action && now - last.at < 3000) return;
    last = { action, at: now };
    // Also announced on the page, which lets the extension's checks see it.
    document.dispatchEvent(new CustomEvent('clockin:command', { detail: action }));
    const label = action === 'clock-in' ? 'Clock in' : 'Clock out';
    chrome.runtime.sendMessage({ type: 'command', action }).then((result) => {
      if (result?.ok && result.confirmed) toast(`Clockin ✓ ${label}`, true);
      else if (result?.ok) toast(tr ? `Clockin: ${label} gönderildi, onay gelmedi` : `Clockin: ${label} sent, not confirmed`, false);
      else if (result?.native === false) openLink(action);
      else toast(tr ? `Clockin: ${label} iletilemedi` : `Clockin: ${label} did not reach Clockin`, false);
    }, () => openLink(action));
  }

  document.addEventListener('click', (event) => {
    // Only a person's press: pages that click their own buttons from script
    // (auto-refresh, tab focus) never count.
    if (!event.isTrusted) return;
    const action = actionFor(event);
    if (action) send(action);
  }, true);
})();
