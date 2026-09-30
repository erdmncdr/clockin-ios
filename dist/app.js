'use strict';
// Downloads use native same-origin links in index.html, independent of JavaScript.

const captions = {timer:'captionTimer',history:'captionHistory',progress:'captionProgress'};
const stage = document.querySelector('#product-stage');
const picker = document.querySelector('.screen-picker');
const pill = picker.querySelector('.picker-pill');
const caption = document.querySelector('.screen-caption');
const calm = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

// The pill slides to the pressed tab. It is measured only when a tab changes or
// the layout does, never during scrolling.
function placePill(animate) {
  const active = picker.querySelector('[aria-pressed="true"]');
  if (!active) return;
  pill.classList.toggle('no-motion', !animate);
  pill.style.width = active.offsetWidth + 'px';
  pill.style.transform = `translateX(${active.offsetLeft}px)`;
}

function setCaption(text, animate) {
  if (caption.textContent === text) return;
  caption.textContent = text;
  if (animate && !calm()) caption.animate([{opacity: 0, transform: 'translateY(6px)'}, {opacity: 1, transform: 'none'}], {duration: 420, easing: 'cubic-bezier(.22,1,.36,1)'});
}

document.querySelectorAll('[data-screen]').forEach(button => {
  button.addEventListener('click', () => {
    const screen = button.dataset.screen;
    if (stage.dataset.active === screen) return;
    stage.dataset.active = screen;
    document.querySelectorAll('[data-screen]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    placePill(true);
    setCaption(ClockinLocale.t(captions[screen]), true);
  });
});

function translateCaption(){setCaption(ClockinLocale.t(captions[stage.dataset.active]), false); placePill(false);}
document.addEventListener('clockin-language', translateCaption);
new ResizeObserver(() => placePill(false)).observe(picker);
translateCaption();
