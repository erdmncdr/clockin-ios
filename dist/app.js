'use strict';
// Set only after the signed installer has been published and verified.
const DOWNLOAD_URL = null;
const dialog = document.querySelector('#download-dialog');
document.querySelectorAll('[data-download]').forEach(button => {
  button.addEventListener('click', () => {
    if (DOWNLOAD_URL) { window.location.assign(DOWNLOAD_URL); return; }
    dialog.showModal();
  });
});
document.querySelectorAll('.dialog-close,.dialog-done').forEach(button => button.addEventListener('click', () => dialog.close()));
dialog.addEventListener('click', event => { if (event.target === dialog) { const rect = dialog.getBoundingClientRect(); if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) dialog.close(); } });

const captions = {
  timer: 'Başlat, mola ver, kaldığın yerden devam et.',
  history: 'Çalışmanın karşılığını gün gün gör.',
  progress: 'Her çalışma seansı, bir adım daha.'
};
const stage = document.querySelector('#product-stage');
document.querySelectorAll('[data-screen]').forEach(button => {
  button.addEventListener('click', () => {
    const screen = button.dataset.screen;
    stage.dataset.active = screen;
    document.querySelectorAll('[data-screen]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    document.querySelector('.screen-caption').textContent = captions[screen];
  });
});
