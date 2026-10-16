'use strict';
const tr = (navigator.language || '').toLowerCase().startsWith('tr');
const T = tr ? {
  intro: 'İş sitenizi açın ve “Butonları seç”e basın. Sonra mesaiyi başlatan ve bitiren butona birer kez tıklayın.',
  ready: 'Bu butonlara bastığınızda Clockin başlar ve biter.',
  site: 'Site', start: 'Başlat', stop: 'Bitir', same: '(aynı buton)',
  pick: 'Butonları seç', repick: 'Butonları yeniden seç', reset: 'Kaldır',
  notWeb: 'Önce iş sitenizin sekmesini açın.',
  denied: 'Clockin bu siteye erişemezse butonları göremez. Tekrar deneyip izin verin.',
} : {
  intro: 'Open your work site and press “Pick buttons”. Then click the button that starts work and the one that ends it.',
  ready: 'Clockin starts and stops when you press these buttons.',
  site: 'Site', start: 'Start', stop: 'End', same: '(same button)',
  pick: 'Pick buttons', repick: 'Pick buttons again', reset: 'Remove',
  notWeb: 'Open your work site’s tab first.',
  denied: 'Clockin can’t see the buttons without access to this site. Try again and allow it.',
};
const $ = (id) => document.getElementById(id);
let tab = null;

function showError(text) { $('error').textContent = text; $('error').hidden = false; }

async function render() {
  const { setup } = await chrome.storage.local.get('setup');
  $('siteLabel').textContent = T.site;
  $('startLabel').textContent = T.start;
  $('stopLabel').textContent = T.stop;
  $('reset').textContent = T.reset;
  if (setup) {
    $('intro').textContent = T.ready;
    $('setup').hidden = false;
    $('site').textContent = new URL(setup.origin).host;
    $('start').textContent = setup.start.text || setup.start.selector;
    $('stop').textContent = setup.same ? `${setup.start.text} ${T.same}` : (setup.stop.text || setup.stop.selector);
    $('pick').textContent = T.repick;
    $('reset').hidden = false;
  } else {
    $('intro').textContent = T.intro;
    $('setup').hidden = true;
    $('pick').textContent = T.pick;
    $('reset').hidden = true;
  }
}

$('pick').addEventListener('click', async () => {
  if (!tab || !/^https?:/.test(tab.url || '')) return showError(T.notWeb);
  const origin = new URL(tab.url).origin;
  // Asked straight from the click, so Chrome shows its permission prompt.
  const granted = await chrome.permissions.request({ origins: [origin + '/*'] });
  if (!granted) return showError(T.denied);
  await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['picker.js'] });
  window.close();
});

$('reset').addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'reset' });
  render();
});

chrome.tabs.query({ active: true, currentWindow: true }).then(([active]) => { tab = active; });
render();
