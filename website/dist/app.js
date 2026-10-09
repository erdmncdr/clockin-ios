'use strict';
(() => {
  const stage = document.querySelector('#product-stage');
  const caption = document.querySelector('.screen-caption');
  const buttons = [...document.querySelectorAll('[data-screen]')];
  const captions = {today:'captionToday',history:'captionHistory',progress:'captionProgress',settings:'captionSettings'};
  function show(screen) {
    stage.dataset.active = screen;
    stage.classList.add('has-selection');
    buttons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.screen === screen)));
    stage.querySelectorAll('[data-image]').forEach(figure => {
      const selected = figure.dataset.image === screen;
      figure.classList.toggle('is-selected', selected);
      figure.toggleAttribute('inert', !selected);
      figure.setAttribute('aria-hidden', String(!selected));
    });
    caption.textContent = ClockinLocale.t(captions[screen]);
  }
  buttons.forEach(button => button.addEventListener('click', () => show(button.dataset.screen)));
  document.addEventListener('clockin-language', () => show(stage.dataset.active));
  show(stage.dataset.active);
})();
