'use strict';
(() => {
  const hero = document.querySelector('.companion');
  const image = document.querySelector('#companion-image');
  const rig = hero.querySelector('.mascot-rig');
  const parts = {body: hero.querySelector('.mascot-body'), sway: hero.querySelector('.mascot-sway'), shadow: hero.querySelector('.mascot-shadow')};
  const speech = document.querySelector('#companion-speech');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const texts = {hello:'hello', working:'working', coffee:'coffee', celebrate:'celebrate'};
  let mood = 'hello', scene = 0;
  let paused = reduced.matches, visible = true, stop = () => {}, change = null;
  let override = false;
  const scenes = ['hello','working','coffee','celebrate'];
  function timers() {
    stop(); clearTimeout(change); change = null;
    const moving = !paused && !reduced.matches && !document.hidden;
    hero.classList.toggle('is-paused', !moving);
    stop = ClockinSprite.play(image, mood, moving && visible, parts);
    if (!moving) return;
    if (visible && !override) change = setTimeout(() => {scene = (scene + 1) % scenes.length; setMood(scenes[scene]);}, 10000);
  }
  function setMood(name, text) {
    mood = name;
    hero.dataset.mood = name;
    // A small pop marks the change of pose; `add` keeps the idle sway running.
    if (!reduced.matches && !paused && name !== hero.dataset.shown) {
      parts.sway.animate([{transform: 'scale(.9)'}, {transform: 'scale(1.035)', offset: .6}, {transform: 'scale(1)'}], {duration: 460, easing: 'cubic-bezier(.22,1,.36,1)', composite: 'add'});
    }
    hero.dataset.shown = name;
    const next = ClockinLocale.t(text || texts[name]);
    if (speech.textContent !== next) {
      speech.textContent = next;
      if (!reduced.matches) speech.animate([{opacity: 0, transform: 'translateY(5px)'}, {opacity: 1, transform: 'none'}], {duration: 380, easing: 'cubic-bezier(.22,1,.36,1)'});
    }
    timers();
  }
  function setPaused(value) {
    paused = reduced.matches || value;
    document.documentElement.classList.toggle('motion-paused', paused);
    document.dispatchEvent(new CustomEvent('clockin-motion', {detail:{paused}}));
    timers();
  }
  document.querySelector('#start-tour').addEventListener('click', () => {
    document.querySelector('#uygulama').scrollIntoView({behavior:paused ? 'instant' : 'smooth',block:'start'});
    document.querySelector('#demo-toggle').focus({preventScroll:true});
  });
  // A tap hops first and changes pose in the air.
  document.querySelector('#meet-companion').addEventListener('click', () => {
    scene = (scene + 1) % scenes.length;
    stop.react?.();
    setTimeout(() => setMood(scenes[scene]), reduced.matches ? 0 : 330);
  });

  // The mascot leans a little toward the pointer, eased every frame until it
  // settles, and only while a fine pointer is over the hero art.
  const art = document.querySelector('.hero-art');
  let target = 0, lean = 0, leanFrame = 0;
  function leanStep() {
    lean += (target - lean) * .12;
    if (Math.abs(target - lean) < .002) lean = target;
    rig.style.transform = lean === 0 ? '' : `translateX(${(lean * 1.6).toFixed(3)}%) rotate(${(lean * 3).toFixed(3)}deg)`;
    leanFrame = lean === target ? 0 : requestAnimationFrame(leanStep);
  }
  function aim(value) {
    target = paused || reduced.matches ? 0 : Math.max(-1, Math.min(1, value));
    if (!leanFrame) leanFrame = requestAnimationFrame(leanStep);
  }
  art.addEventListener('pointermove', event => {
    if (event.pointerType !== 'mouse') return;
    const box = art.getBoundingClientRect();
    aim(((event.clientX - box.left) / box.width - .5) * 2);
  });
  art.addEventListener('pointerleave', () => aim(0));
  document.querySelectorAll('[data-download]').forEach(button => {
    const greet = () => {override = true; setMood('celebrate', 'seeYou');};
    const restore = () => {override = false; setMood(scenes[scene]);};
    button.addEventListener('pointerenter', event => {if(event.pointerType !== 'touch') greet();});
    button.addEventListener('pointerleave', restore);
    button.addEventListener('focus', greet);
    button.addEventListener('blur', restore);
  });
  new IntersectionObserver(entries => {visible = entries[0].isIntersecting; timers();}, {threshold:0.1}).observe(hero);
  document.addEventListener('visibilitychange', timers);
  reduced.addEventListener('change', () => setPaused(reduced.matches));
  speech.style.whiteSpace = 'pre-line';
  document.addEventListener('clockin-language',()=>{speech.textContent=ClockinLocale.t(override?'seeYou':texts[mood]);});
  setMood('hello');
  setPaused(paused);
})();
