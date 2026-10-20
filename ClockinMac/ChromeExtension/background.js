'use strict';
// Keeps the click watcher registered for the one site the buttons were picked
// on (and the picker there while picking), and passes presses to Clockin
// through Chrome's native messaging, which also says whether they counted.
const WATCHER = 'clockin-watch';
const PICKER = 'clockin-picker';
const HOST = 'com.erdmncdr.clockin';

async function unregister(id) {
  const existing = await chrome.scripting.getRegisteredContentScripts({ ids: [id] });
  if (existing.length) await chrome.scripting.unregisterContentScripts({ ids: [id] });
}

async function registerFor(id, origin, file) {
  await unregister(id);
  if (!origin) return;
  await chrome.scripting.registerContentScripts([{
    id, matches: [origin + '/*'], js: [file], runAt: 'document_idle', allFrames: false,
    persistAcrossSessions: id === WATCHER,
  }]);
}

function badge(text, color) {
  chrome.action.setBadgeText({ text });
  chrome.action.setBadgeBackgroundColor({ color });
  setTimeout(() => chrome.action.setBadgeText({ text: '' }), 4000);
}

async function command({ action }) {
  let result;
  try {
    result = await chrome.runtime.sendNativeMessage(HOST, { action });
  } catch (error) {
    // Older Clockin without the native host: the page opens a clockin:// link.
    result = { ok: false, native: false, error: String(error?.message || error) };
  }
  const lastEvent = { action, at: Date.now(), ok: !!result?.ok, confirmed: !!result?.confirmed, native: result?.native !== false };
  await chrome.storage.local.set({ lastEvent });
  if (lastEvent.native) badge(lastEvent.confirmed ? '✓' : '!', lastEvent.confirmed ? '#2e9d5b' : '#d9822b');
  return result;
}

const handlers = {
  command,
  async miss({ miss }) {
    await chrome.storage.local.set({ lastMiss: miss });
  },
  // Registered before the first click, so a reload right after it brings the
  // picker back for the second button.
  async 'start-pick'({ origin }) {
    await chrome.storage.local.set({ picking: { origin, at: Date.now() } });
    await chrome.storage.local.remove('pending');
    await registerFor(PICKER, origin, 'picker.js');
  },
  async save({ setup }) {
    await chrome.storage.local.set({ setup });
    await chrome.storage.local.remove('lastMiss');
    await chrome.storage.local.remove(['picking', 'pending']);
    await unregister(PICKER);
    await registerFor(WATCHER, setup.origin, 'watch.js');
  },
  async 'cancel-pick'() {
    await chrome.storage.local.remove(['picking', 'pending']);
    await unregister(PICKER);
  },
  async reset() {
    await chrome.storage.local.remove(['setup', 'picking', 'pending', 'lastEvent', 'lastMiss']);
    await unregister(PICKER);
    await unregister(WATCHER);
  },
};

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  const handler = handlers[message?.type];
  if (!handler) return false;
  handler(message).then((value) => reply(value ?? { ok: true }), (error) => reply({ ok: false, error: String(error) }));
  return true;
});

// After an update of the extension files, register again from what was saved.
chrome.runtime.onInstalled.addListener(async () => {
  const { setup } = await chrome.storage.local.get('setup');
  if (setup) await registerFor(WATCHER, setup.origin, 'watch.js');
});
