'use strict';
// Keeps the click watcher registered for the one site the buttons were picked on.
const WATCHER = 'clockin-watch';

async function register(setup) {
  const existing = await chrome.scripting.getRegisteredContentScripts({ ids: [WATCHER] });
  if (existing.length) await chrome.scripting.unregisterContentScripts({ ids: [WATCHER] });
  if (!setup) return;
  await chrome.scripting.registerContentScripts([{
    id: WATCHER,
    matches: [setup.origin + '/*'],
    js: ['watch.js'],
    runAt: 'document_idle',
    allFrames: true,
    persistAcrossSessions: true,
  }]);
}

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (message?.type === 'save' && message.setup) {
    chrome.storage.local.set({ setup: message.setup })
      .then(() => register(message.setup))
      .then(() => reply({ ok: true }), (error) => reply({ ok: false, error: String(error) }));
    return true;
  }
  if (message?.type === 'reset') {
    chrome.storage.local.remove('setup').then(() => register(null)).then(() => reply({ ok: true }));
    return true;
  }
  return false;
});

// After an update of the extension files, register again from what was saved.
chrome.runtime.onInstalled.addListener(async () => {
  const { setup } = await chrome.storage.local.get('setup');
  if (setup) await register(setup);
});
