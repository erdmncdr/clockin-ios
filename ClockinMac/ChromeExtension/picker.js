'use strict';
// Injected from the popup, and again after a reload while picking. The person
// clicks the button that starts work, then the one that ends it. The clicks go
// through to the site, so after Clock in the site can show its Clock out button
// (or reload the page); the first pick is kept until the second one is made.
(async () => {
  if (window.__clockinPicker) return;
  window.__clockinPicker = true;

  const tr = (navigator.language || '').toLowerCase().startsWith('tr');
  const T = tr ? {
    start: 'Clockin 1/2: mesaiyi BAŞLATAN butona tıklayın. Sitede mesainiz başlar.',
    stop: 'Clockin 2/2: şimdi mesaiyi BİTİREN butona tıklayın.',
    cancel: 'Vazgeç',
    done: 'Hazır. Bu butonlara bastığınızda Clockin başlar ve biter.',
  } : {
    start: 'Clockin 1/2: click the button that STARTS work. Your shift starts on the site.',
    stop: 'Clockin 2/2: now click the button that ENDS work.',
    cancel: 'Cancel',
    done: 'Done. Clockin now starts and stops with these buttons.',
  };
  const CLICKABLE = 'button, a, [role="button"], input[type="button"], input[type="submit"]';

  // Picking runs only after "Pick buttons" on this site, for ten minutes at most.
  const { picking, pending } = await chrome.storage.local.get(['picking', 'pending']);
  if (!picking || picking.origin !== location.origin) { window.__clockinPicker = false; return; }
  if (Date.now() - picking.at > 10 * 60 * 1000) {
    chrome.runtime.sendMessage({ type: 'cancel-pick' });
    window.__clockinPicker = false;
    return;
  }
  let start = pending && pending.origin === location.origin ? pending.start : null;

  const bar = document.createElement('div');
  bar.setAttribute('style', 'all:initial;position:fixed;z-index:2147483647;top:12px;left:50%;transform:translateX(-50%);' +
    'display:flex;gap:10px;align-items:center;padding:10px 14px;border-radius:12px;background:#111827;color:#fff;' +
    'font:600 14px -apple-system,BlinkMacSystemFont,sans-serif;box-shadow:0 10px 30px rgba(0,0,0,.35)');
  const message = document.createElement('span');
  const cancelButton = document.createElement('button');
  cancelButton.setAttribute('style', 'all:initial;cursor:pointer;padding:6px 10px;border-radius:8px;background:#374151;color:#fff;' +
    'font:600 13px -apple-system,BlinkMacSystemFont,sans-serif');
  cancelButton.textContent = T.cancel;
  bar.append(message, cancelButton);
  const outline = document.createElement('div');
  outline.setAttribute('style', 'all:initial;position:fixed;z-index:2147483646;pointer-events:none;border:3px solid #f78a18;' +
    'border-radius:6px;display:none');
  document.documentElement.append(outline, bar);
  message.textContent = start ? T.stop : T.start;

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

  const describe = (el) => ({ selector: selectorFor(el), text: label(el), tag: el.tagName.toLowerCase() });

  function move(event) {
    const el = target(event);
    if (!el) { outline.style.display = 'none'; return; }
    const rect = el.getBoundingClientRect();
    Object.assign(outline.style, {
      display: 'block', left: rect.left - 3 + 'px', top: rect.top - 3 + 'px',
      width: rect.width + 'px', height: rect.height + 'px',
    });
  }

  // Read before the site handles the click (it may relabel or replace the
  // button, or reload the page); the click itself is left alone.
  function click(event) {
    const el = target(event);
    if (!el) return;
    if (!start) {
      start = describe(el);
      // Written straight away: the site may reload the page right after this click.
      chrome.storage.local.set({ pending: { origin: location.origin, start } });
      message.textContent = T.stop;
    } else {
      const end = describe(el);
      const setup = { origin: location.origin, start, stop: end, same: end.selector === start.selector };
      stop();
      cancelButton.remove();
      message.textContent = T.done;
      chrome.runtime.sendMessage({ type: 'save', setup });
      setTimeout(() => bar.remove(), 3500);
    }
  }

  function stop() {
    document.removeEventListener('mousemove', move, true);
    document.removeEventListener('click', click, true);
    document.removeEventListener('keydown', key, true);
    outline.remove();
  }

  function cancel() {
    stop();
    bar.remove();
    chrome.runtime.sendMessage({ type: 'cancel-pick' });
  }

  function key(event) { if (event.key === 'Escape') cancel(); }

  cancelButton.addEventListener('click', cancel);
  document.addEventListener('mousemove', move, true);
  document.addEventListener('click', click, true);
  document.addEventListener('keydown', key, true);
})();
