// Loads the Clockin Chrome extension into a throwaway Chrome profile over the DevTools pipe,
// picks the test page's button, then presses it and records what the watcher does.
import { spawn } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// launch: 'logic' (the extension copy does not open links) or 'link'.
const [extPath, pageURL, mode = 'toggle', launch = 'logic'] = process.argv.slice(2);
const profile = mkdtempSync(join(tmpdir(), 'clockin-chrome-'));
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--remote-debugging-pipe', '--enable-unsafe-extension-debugging',
  `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });
const out = chrome.stdio[3], inp = chrome.stdio[4];
let id = 0, buffer = '';
const pending = new Map(), events = [];
inp.on('data', (chunk) => {
  buffer += chunk;
  let i;
  while ((i = buffer.indexOf('\0')) >= 0) {
    const msg = JSON.parse(buffer.slice(0, i)); buffer = buffer.slice(i + 1);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
    else if (msg.method) events.push(msg);
  }
});
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const mid = ++id;
  pending.set(mid, (msg) => msg.error ? reject(new Error(method + ': ' + msg.error.message)) : resolve(msg.result));
  out.write(JSON.stringify({ id: mid, method, params, sessionId }) + '\0');
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, text) => { results.push(`${ok ? 'ok' : 'FAILED'}: ${text}`); };

try {
  const { id: extId } = await send('Extensions.loadUnpacked', { path: extPath });
  check(!!extId, 'the extension loads');
  const { targetId } = await send('Target.createTarget', { url: pageURL });
  const { sessionId: page } = await send('Target.attachToTarget', { targetId, flatten: true });
  await send('Page.enable', {}, page);
  await send('Runtime.enable', {}, page);
  await sleep(1500);
  const worker = (await send('Target.getTargets')).targetInfos.find((t) => t.type === 'service_worker' && t.url.includes(extId));
  const { sessionId: sw } = await send('Target.attachToTarget', { targetId: worker.targetId, flatten: true });
  const evalSW = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sw)).result.value;
  const evalPage = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, page)).result.value;
  const clickAt = async (selectorExpression) => {
    const box = await evalPage(`(() => { const r = (${selectorExpression}).getBoundingClientRect(); return {x: r.x + r.width / 2, y: r.y + r.height / 2}; })()`);
    for (const type of ['mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: 'left', clickCount: 1 }, page);
    }
  };

  // Pick: the start button, then the end button. Both clicks reach the site,
  // which may relabel the button, show another one or reload the page.
  await evalSW(`new Promise(r => chrome.runtime.onMessage.hasListeners() ? r() : r()).then(() => chrome.storage.local.set({ picking: { origin: ${JSON.stringify(new URL(pageURL).origin)}, at: Date.now() } })).then(() => chrome.scripting.registerContentScripts([{ id: 'clockin-picker', matches: [${JSON.stringify(new URL(pageURL).origin + '/*')}], js: ['picker.js'], runAt: 'document_idle' }]))`);
  const injected = await evalSW(`chrome.tabs.query({}).then(tabs => { const t = tabs.find(t => (t.url || '').startsWith(${JSON.stringify(pageURL)})); return t ? chrome.scripting.executeScript({target: {tabId: t.id}, files: ['picker.js']}).then(() => 'injected', e => 'error: ' + e.message) : 'no tab: ' + JSON.stringify(tabs.map(t => t.url)); })`);
  check(injected === 'injected', 'the picker is injected: ' + injected);
  await sleep(500);
  const startButton = { toggle: `document.getElementById('toggle')`, div: `document.querySelector('.start')` }[mode] ?? `document.querySelectorAll('button')[0]`;
  await clickAt(startButton);
  await sleep(mode === 'reload' ? 1800 : 400);
  check(await evalPage(`document.getElementById('status').textContent`) === 'working', 'the start pick reaches the site, so it can show Clock out');
  check(await evalPage(`[...document.querySelectorAll('span')].some(s => /2\\/2/.test(s.textContent))`), 'the picker asks for the end button' + (mode === 'reload' ? ' after the reload' : ''));
  const endButton = { two: `document.querySelectorAll('button')[1]`, div: `document.querySelector('.fake-button .label')` }[mode] ?? startButton;
  await clickAt(endButton);
  await sleep(mode === 'reload' ? 1800 : 800);
  check(await evalPage(`document.getElementById('status').textContent`) === 'idle', 'the end pick reaches the site too');
  const setup = await evalSW(`chrome.storage.local.get(['setup', 'pending']).then(r => ({ ...r.setup, pendingLeft: !!r.pending }))`);
  check(setup && setup.start?.text === 'Clock in' && setup.stop?.text === 'Clock out' && (mode === 'reload' || setup.same === (mode === 'toggle')) && !setup.pendingLeft,
        'the pick is saved: ' + JSON.stringify(setup));
  const registered = await evalSW(`chrome.scripting.getRegisteredContentScripts().then(s => s.map(x => x.id + ' ' + x.matches.join()))`);
  check(registered.length === 1 && registered[0] === 'clockin-watch ' + new URL(pageURL).origin + '/*', 'only the watcher stays registered, for that site only: ' + registered);

  // Load the page fresh so the registered watcher runs, then work a shift.
  const lastEvent = () => evalSW(`chrome.storage.local.get('lastEvent').then(r => r.lastEvent?.action ?? null)`);
  await send('Page.navigate', { url: pageURL }, page);
  await sleep(1500);
  events.length = 0;
  await clickAt(startButton);
  await sleep(mode === 'reload' ? 1800 : 700);
  check(await evalPage(`document.getElementById('status').textContent`) === 'working', 'the site still handles its own click');
  check(await lastEvent() === 'clock-in', 'the start press is detected');
  if (launch === 'link') {
    // Headless Chrome keeps its "Open Clockin?" prompt unanswered, which also
    // blocks later clicks, so this run stops after the first link.
    const urls = events.filter((e) => e.method === 'Page.frameRequestedNavigation').map((e) => e.params.url);
    check(urls.includes('clockin://clock-in'), 'Chrome receives the clockin://clock-in link: ' + JSON.stringify(urls));
  } else {
    await clickAt(endButton);
    await sleep(mode === 'reload' ? 1800 : 700);
    check(await evalPage(`document.getElementById('status').textContent`) === 'idle', 'the end press reaches the site too');
    check(await lastEvent() === 'clock-out', 'the end press is detected');
    if (mode !== 'reload') {
      const commands = await evalPage(`window.__commands`);
      check(JSON.stringify(commands) === JSON.stringify(['clock-in', 'clock-out']), 'the watcher sends clock-in then clock-out: ' + JSON.stringify(commands));
    }
  }
} catch (error) {
  check(false, String(error));
} finally {
  console.log(results.join('\n'));
  chrome.kill();
  process.exit(results.some((r) => r.startsWith('FAILED')) ? 1 : 0);
}
