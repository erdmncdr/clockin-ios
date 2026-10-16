'use strict';
// Injected once from the popup. The person clicks the button that starts work,
// then the one that ends it (or says it is the same button). Clicks are caught
// here, so the site does not react to them.
(() => {
  if (window.__clockinPicker) return;
  window.__clockinPicker = true;

  const tr = (navigator.language || '').toLowerCase().startsWith('tr');
  const T = tr ? {
    start: 'Clockin: mesaiyi BAŞLATAN butona tıklayın.',
    stop: 'Şimdi mesaiyi BİTİREN butona tıklayın.',
    same: 'Aynı buton',
    cancel: 'Vazgeç',
    done: 'Hazır. Bu butonlara bastığınızda Clockin başlar ve biter.',
  } : {
    start: 'Clockin: click the button that STARTS work.',
    stop: 'Now click the button that ENDS work.',
    same: 'Same button',
    cancel: 'Cancel',
    done: 'Done. Clockin now starts and stops with these buttons.',
  };
  const CLICKABLE = 'button, a, [role="button"], input[type="button"], input[type="submit"]';

  const bar = document.createElement('div');
  bar.setAttribute('style', 'all:initial;position:fixed;z-index:2147483647;top:12px;left:50%;transform:translateX(-50%);' +
    'display:flex;gap:10px;align-items:center;padding:10px 14px;border-radius:12px;background:#111827;color:#fff;' +
    'font:600 14px -apple-system,BlinkMacSystemFont,sans-serif;box-shadow:0 10px 30px rgba(0,0,0,.35)');
  const message = document.createElement('span');
  const sameButton = document.createElement('button');
  const cancelButton = document.createElement('button');
  for (const button of [sameButton, cancelButton]) {
    button.setAttribute('style', 'all:initial;cursor:pointer;padding:6px 10px;border-radius:8px;background:#374151;color:#fff;' +
      'font:600 13px -apple-system,BlinkMacSystemFont,sans-serif');
  }
  sameButton.textContent = T.same;
  sameButton.style.display = 'none';
  cancelButton.textContent = T.cancel;
  bar.append(message, sameButton, cancelButton);
  const outline = document.createElement('div');
  outline.setAttribute('style', 'all:initial;position:fixed;z-index:2147483646;pointer-events:none;border:3px solid #f78a18;' +
    'border-radius:6px;display:none');
  document.documentElement.append(outline, bar);
  message.textContent = T.start;

  const picks = [];
  const label = (el) => (el.innerText || el.value || el.getAttribute('aria-label') || '').trim().replace(/\s+/g, ' ').slice(0, 80);
  const target = (event) => {
    const el = event.target instanceof Element ? event.target : null;
    if (!el || bar.contains(el)) return null;
    return el.closest(CLICKABLE) || el;
  };

  function selectorFor(el) {
    const unique = (selector) => { try { return document.querySelectorAll(selector).length === 1; } catch (_) { return false; } };
    if (el.id && unique('#' + CSS.escape(el.id))) return '#' + CSS.escape(el.id);
    const tag = el.tagName.toLowerCase();
    for (const attribute of ['data-testid', 'data-test', 'data-qa', 'name', 'aria-label']) {
      const value = el.getAttribute(attribute);
      if (value) {
        const selector = `${tag}[${attribute}=${JSON.stringify(value)}]`;
        if (unique(selector)) return selector;
      }
    }
    const parts = [];
    for (let node = el; node && node !== document.body && node.nodeType === 1; node = node.parentElement) {
      const name = node.tagName.toLowerCase();
      const siblings = node.parentElement ? [...node.parentElement.children].filter((child) => child.tagName === node.tagName) : [];
      parts.unshift(siblings.length > 1 ? `${name}:nth-of-type(${siblings.indexOf(node) + 1})` : name);
    }
    return 'body > ' + parts.join(' > ');
  }

  function describe(el) {
    return { selector: selectorFor(el), text: label(el), tag: el.tagName.toLowerCase() };
  }

  function block(event) {
    if (bar.contains(event.target)) return;
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
  }

  function move(event) {
    const el = target(event);
    if (!el) { outline.style.display = 'none'; return; }
    const rect = el.getBoundingClientRect();
    Object.assign(outline.style, {
      display: 'block', left: rect.left - 3 + 'px', top: rect.top - 3 + 'px',
      width: rect.width + 'px', height: rect.height + 'px',
    });
  }

  function click(event) {
    const el = target(event);
    if (!el) return;
    block(event);
    picks.push(describe(el));
    if (picks.length === 1) {
      message.textContent = T.stop;
      sameButton.style.display = '';
    } else {
      finish(false);
    }
  }

  const events = ['pointerdown', 'pointerup', 'mousedown', 'mouseup', 'touchstart', 'touchend'];
  function stop() {
    document.removeEventListener('mousemove', move, true);
    document.removeEventListener('click', click, true);
    for (const name of events) document.removeEventListener(name, block, true);
    document.removeEventListener('keydown', key, true);
    outline.remove();
    window.__clockinPicker = false;
  }

  function finish(same) {
    const start = picks[0];
    const end = same ? start : picks[1];
    const setup = { origin: location.origin, start, stop: end, same: same || end.selector === start.selector };
    stop();
    sameButton.remove();
    cancelButton.remove();
    message.textContent = T.done;
    chrome.runtime.sendMessage({ type: 'save', setup });
    setTimeout(() => bar.remove(), 3500);
  }

  function key(event) {
    if (event.key === 'Escape') { stop(); bar.remove(); }
  }

  sameButton.addEventListener('click', () => { if (picks.length === 1) finish(true); });
  cancelButton.addEventListener('click', () => { stop(); bar.remove(); });
  document.addEventListener('mousemove', move, true);
  document.addEventListener('click', click, true);
  for (const name of events) document.addEventListener(name, block, true);
  document.addEventListener('keydown', key, true);
})();
