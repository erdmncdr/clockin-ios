'use strict';
const tr = (navigator.language || '').toLowerCase().startsWith('tr');
const T = tr ? {
  intro: 'İş sitenizi açın ve “Butonları seç”e basın. Önce mesaiyi başlatan butona, ardından bitiren butona tıklayın; ikisi de sitede gerçekten çalışır.',
  ready: 'Bu butonlara bastığınızda Clockin başlar ve biter.',
  site: 'Site', start: 'Başlat', stop: 'Bitir',
  pick: 'Butonları seç', repick: 'Butonları yeniden seç', reset: 'Kaldır',
  last: 'Son algılanan', in: 'Clock in', out: 'Clock out',
  miss: (label, time) => `Sayılmayan tıklama: “${label}” · ${time}. Site butonu değiştirmiş olabilir; butonları yeniden seçin.`,
  notWeb: 'Önce iş sitenizin sekmesini açın.',
  denied: 'Clockin bu siteye erişemezse butonları göremez. Tekrar deneyip izin verin.',
} : {
  intro: 'Open your work site and press “Pick buttons”. Click the button that starts work, then the one that ends it; both really work on the site.',
  ready: 'Clockin starts and stops when you press these buttons.',
  site: 'Site', start: 'Start', stop: 'End',
  pick: 'Pick buttons', repick: 'Pick buttons again', reset: 'Remove',
  last: 'Last detected', in: 'Clock in', out: 'Clock out',
  miss: (label, time) => `Press not counted: “${label}” · ${time}. The site may have changed the button; pick the buttons again.`,
  notWeb: 'Open your work site’s tab first.',
  denied: 'Clockin can’t see the buttons without access to this site. Try again and allow it.',
};
const $ = (id) => document.getElementById(id);
let tab = null;

function showError(text) { $('error').textContent = text; $('error').hidden = false; }

async function render() {
  const { setup, lastEvent, lastMiss } = await chrome.storage.local.get(['setup', 'lastEvent', 'lastMiss']);
  const when = (at) => new Date(at).toLocaleString(tr ? 'tr-TR' : undefined, { dateStyle: 'short', timeStyle: 'short' });
  if (setup && lastEvent) {
    // Shows whether the last press reached the extension at all.
    $('last').textContent = `${T.last}: ${lastEvent.action === 'clock-in' ? T.in : T.out} · ${when(lastEvent.at)}`;
    $('last').hidden = false;
  }
  // Only while it is the newest thing that happened.
  if (setup && lastMiss && (!lastEvent || lastMiss.at > lastEvent.at)) {
    $('miss').textContent = T.miss(lastMiss.text, when(lastMiss.at));
    $('miss').hidden = false;
  }
  $('siteLabel').textContent = T.site;
  $('startLabel').textContent = T.start;
  $('stopLabel').textContent = T.stop;
  $('reset').textContent = T.reset;
  if (setup) {
    $('intro').textContent = T.ready;
    $('setup').hidden = false;
    $('site').textContent = new URL(setup.origin).host;
    $('start').textContent = setup.start.text || setup.start.selector;
    $('stop').textContent = setup.stop.text || setup.stop.selector;
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
  await chrome.runtime.sendMessage({ type: 'start-pick', origin });
  await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['picker.js'] });
  window.close();
});

$('reset').addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'reset' });
  render();
});

chrome.tabs.query({ active: true, currentWindow: true }).then(([active]) => { tab = active; });
render();
