'use strict';
(() => {
  const hero = document.querySelector('.companion');
  const image = document.querySelector('#companion-image');
  const speech = document.querySelector('#companion-speech');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const moods = {
    hello: {frames:['assets/mascot-hello.png'], text:'hello'},
    working: {frames:[1,2,3,4].map(n => `assets/companion/frame${n}.png`), text:'working'},
    coffee: {frames:[1,2,3,4].map(n => `assets/companion/coffee${n}.png`), text:'coffee'},
    celebrate: {frames:['assets/companion/celebrate.png'], text:'celebrate'}
  };
  let mood = 'hello', frame = 0, scene = 0;
  let paused = reduced.matches, visible = true, tick = null, change = null;
  let override = false;
  const scenes = ['hello','working','coffee','celebrate'];
  const preloads = [];
  Object.values(moods).flatMap(m => m.frames).forEach(src => {const img = new Image(); img.src = src; preloads.push(img);});
  function paint() {
    const frames = moods[mood].frames;
    image.src = frames[frame % frames.length];
  }
  function timers() {
    clearInterval(tick); clearTimeout(change); tick = null; change = null;
    const moving = !paused && !reduced.matches && !document.hidden;
    hero.classList.toggle('is-paused', !moving);
    if (!moving) return;
    if (visible) tick = setInterval(() => {frame++; paint();}, 280);
    if (visible && !override) change = setTimeout(() => {scene = (scene + 1) % scenes.length; setMood(scenes[scene]);}, 10000);
  }
  function setMood(name, text) {
    mood = name; frame = 0;
    hero.dataset.mood = name;
    speech.textContent = ClockinLocale.t(text || moods[name].text);
    paint(); timers();
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
  document.querySelector('#meet-companion').addEventListener('click', () => {
    scene = (scene + 1) % scenes.length;
    setMood(scenes[scene]);
  });
  document.querySelectorAll('[data-download]').forEach(button => {
    const greet = () => {override = true; setMood('celebrate', DOWNLOAD_URL ? 'seeYou' : 'soon');};
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
  document.addEventListener('clockin-language',()=>{speech.textContent=ClockinLocale.t(override?(DOWNLOAD_URL?'seeYou':'soon'):moods[mood].text);});
  setMood('hello');
  setPaused(paused);
})();
