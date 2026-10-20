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
  // A label without its digits and punctuation, so "Clock out (02:13)" is still "clock out".
  const core = (text) => norm(text).replace(/[\d\p{P}\p{S}]+/gu, ' ').replace(/\s+/g, ' ').trim();
  const sameText = (a, b) => {
    if (!a || !b) return false;
    const [x, y] = [core(a), core(b)];
    // Icon-only labels have nothing left after stripping: compare them whole.
    return x && y ? x === y : norm(a) === norm(b);
  };

  // How much a clicked element looks like a picked one. No single trait
  // decides: a banner added above the button changes its position (the
  // selector), and a site may restyle or relabel it, but rarely all at once.
  // A label that clearly differs counts against, so after the site removes
  // its Clock in button the Clock out that slides into its place is not
  // taken for it.
  function score(el, pick, { ignoreText = false } = {}) {
    if (!pick) return 0;
    let points = 0;
    try { if (pick.selector && el.matches(pick.selector)) points += 3; } catch (_) {}
    if (pick.id && el.id === pick.id) points += 5;
    const testid = el.getAttribute('data-testid') || el.getAttribute('data-test') || el.getAttribute('data-qa');
    if (pick.testid && testid === pick.testid) points += 5;
    if (el.tagName.toLowerCase() === pick.tag) points += 1;
    if (pick.aria && el.getAttribute('aria-label') === pick.aria) points += 2;
    if (pick.classes?.length) {
      const shared = pick.classes.filter((name) => el.classList.contains(name)).length;
      if (shared * 2 >= pick.classes.length) points += 2;
    }
    if (!ignoreText && pick.text) points += sameText(textOf(el), pick.text) ? 3 : -3;
    return points;
  }

  // Picks saved by Clockin 2.0.20 have only selector, text and tag.
  const legacy = !setup.start?.classes;
  const NEED = legacy ? 4 : 5;

  // The picked element may be the clicked one or one it sits in: sites build
  // buttons from divs and spans as often as from <button>.
  function actionFor(path) {
    for (const node of path) {
      if (!(node instanceof Element) || node === document.body || node === document.documentElement) continue;
      if (setup.same) {
        // One button that changes its label: its start label means "clock in".
        const label = textOf(node);
        const known = sameText(label, setup.start.text) || sameText(label, setup.stop?.text);
        const points = Math.max(score(node, setup.start, { ignoreText: true }), score(node, setup.stop, { ignoreText: true })) + (known ? 3 : 0);
        if (points >= 4) return sameText(label, setup.start.text) ? 'clock-in' : 'clock-out';
        continue;
      }
      const inPoints = score(node, setup.start);
      const outPoints = score(node, setup.stop);
      if (Math.max(inPoints, outPoints) < NEED || inPoints === outPoints) continue;
      return inPoints > outPoints ? 'clock-in' : 'clock-out';
    }
    return null;
  }

  // A press on something labelled like a picked button that still did not
  // count. Kept for the popup, so a missed Clock out can be told apart from a
  // press that never reached the page.
  function nearMiss(path) {
    for (const node of path) {
      if (!(node instanceof Element) || node === document.body) break;
      const label = textOf(node);
      if (!label || label.length > 60) continue;
      const action = sameText(label, setup.start.text) ? 'clock-in' : sameText(label, setup.stop?.text) ? 'clock-out' : null;
      if (action) return { action, text: label.slice(0, 60), tag: node.tagName.toLowerCase(), at: Date.now() };
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

  // Decided at the press as well: some sites remove or replace the button
  // before the click lands, and the click then reaches only its container.
  let pressed = null;
  document.addEventListener('pointerdown', (event) => {
    if (!event.isTrusted) return;
    const action = actionFor(event.composedPath());
    pressed = action ? { action, at: Date.now() } : null;
  }, true);

  document.addEventListener('click', (event) => {
    // Only a person's press: pages that click their own buttons from script
    // (auto-refresh, tab focus) never count.
    if (!event.isTrusted) return;
    const path = event.composedPath();
    let action = actionFor(path);
    if (!action && pressed && Date.now() - pressed.at < 1500) action = pressed.action;
    pressed = null;
    if (action) return send(action);
    const miss = nearMiss(path);
    if (miss) chrome.runtime.sendMessage({ type: 'miss', miss }).catch(() => {});
  }, true);
})();
