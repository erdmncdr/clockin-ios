'use strict';
// Keeps the click watcher registered for the one site the buttons were picked
// on, and the picker registered there while picking, so it survives a reload.
const WATCHER = 'clockin-watch';
const PICKER = 'clockin-picker';

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

const handlers = {
  // Registered before the first click, so a reload right after it brings the
  // picker back for the second button.
  async 'start-pick'({ origin }) {
    await chrome.storage.local.set({ picking: { origin, at: Date.now() } });
    await chrome.storage.local.remove('pending');
    await registerFor(PICKER, origin, 'picker.js');
  },
  async save({ setup }) {
    await chrome.storage.local.set({ setup });
    await chrome.storage.local.remove(['picking', 'pending']);
    await unregister(PICKER);
    await registerFor(WATCHER, setup.origin, 'watch.js');
  },
  async 'cancel-pick'() {
    await chrome.storage.local.remove(['picking', 'pending']);
    await unregister(PICKER);
  },
  async reset() {
    await chrome.storage.local.remove(['setup', 'picking', 'pending']);
    await unregister(PICKER);
    await unregister(WATCHER);
  },
};

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  const handler = handlers[message?.type];
  if (!handler) return false;
  handler(message).then(() => reply({ ok: true }), (error) => reply({ ok: false, error: String(error) }));
  return true;
});

// After an update of the extension files, register again from what was saved.
chrome.runtime.onInstalled.addListener(async () => {
  const { setup } = await chrome.storage.local.get('setup');
  if (setup) await registerFor(WATCHER, setup.origin, 'watch.js');
});
