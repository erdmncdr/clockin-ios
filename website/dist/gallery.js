'use strict';
(() => {
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const tall = matchMedia('(min-height: 650px)');
  const nativeScroll = CSS.supports('animation-timeline: view()');
  const world = document.querySelector('.world');
  const worldStage = world.querySelector('.world-stage');
  const panels = [...world.querySelectorAll('[data-chapter]')];
  const moods = ['hello', 'working', 'tired', 'celebrate', 'angry'];
  const mascot = document.querySelector('#world-mascot');
  const moodArt = mascot.closest('.mood-art');
  const progressBar = world.querySelector('.world-progress > span');
  const layers = [...world.querySelectorAll('.outfit-layer')];
  const reveals = new Set();
  const t = key => ClockinLocale.t(key);
  const clamp = value => Math.max(0, Math.min(1, value));
  const pinned = () => !reduced.matches && tall.matches;
  let worldVisible = false, mascotVisible = false, frame = 0, chapter = -1, mood = 'hello';
  let lastMood = -1, room = -1, rank = -1, spriteKey = '', stopSprite = () => {};
  function sprite() {
    const moving = mascotVisible && (!pinned() || chapter === 0) && !reduced.matches && !document.hidden;
    const key = `${mood}:${moving}`;
    if (key === spriteKey) return;
    spriteKey = key; stopSprite();
    stopSprite = ClockinSprite.play(mascot, mood, moving, {body: mascot.closest('.mascot-body'), sway: mascot.closest('.mascot-sway')});
  }
  function setMood(index) {
    mood = moods[index];
    world.querySelectorAll('[data-world-mood]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.worldMood === mood)));
    document.querySelector('#mood-caption').textContent = t('mood' + mood[0].toUpperCase() + mood.slice(1));
    mascot.alt = t('worldMascotAlt') + ' — ' + document.querySelector('#mood-caption').textContent;
    sprite();
  }
  function setGallery(type, index) {
    if (type === 'room') room = index; else rank = index;
    world.querySelectorAll(`[data-${type}]`).forEach(figure => {
      const active = Number(figure.dataset[type]) === index;
      figure.classList.toggle('is-active', active);
      figure.setAttribute('aria-hidden', String(pinned() && !active));
    });
    world.querySelectorAll(`[data-${type}-select]`).forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset[type + 'Select']) === index)));
  }
  function setChapter(index) {
    chapter = index;
    panels.forEach((panel, i) => {
      panel.classList.toggle('is-active', i === index);
      const hidden = pinned() && i !== index;
      panel.toggleAttribute('inert', hidden);
      panel.setAttribute('aria-hidden', String(hidden));
    });
    world.querySelectorAll('[data-world]').forEach(button => button.setAttribute('aria-current', String(Number(button.dataset.world) === index)));
    sprite();
  }
  function worldGeometry() {
    return {top: world.getBoundingClientRect().top + scrollY, distance: Math.max(1, world.offsetHeight - worldStage.offsetHeight)};
  }
  function go(chapterIndex, fraction = .08) {
    if (!pinned()) return;
    const {top, distance} = worldGeometry();
    // Immediate native position keeps the selected chapter predictable; no scroll trapping.
    window.scrollTo({top: top + distance * ((chapterIndex + fraction) / 4), behavior: 'instant'});
    schedule();
  }
  function paintWorld() {
    if (!pinned() || !worldVisible) return;
    const {top, distance} = worldGeometry();
    const progress = clamp((scrollY - top) / distance);
    const index = Math.min(3, Math.floor(progress * 4));
    const local = Math.min(.99999, progress * 4 - index);
    progressBar.style.transform = `scaleX(${progress.toFixed(4)})`;
    if (chapter !== index) setChapter(index);
    if (index === 0) {
      const m = Math.min(4, Math.floor(local * 5));
      if (m !== lastMood) { lastMood = m; setMood(m); }
    } else if (index === 1) {
      layers.forEach((layer, i) => {
        const p = clamp((local - i * .25) / .22);
        const ease = 1 - Math.pow(1 - p, 3);
        const x = [-105, 100, -80][i] * (1 - ease);
        const y = [-90, -55, 95][i] * (1 - ease);
        layer.style.transform = `translate(${x.toFixed(2)}px,${y.toFixed(2)}px) rotate(${((1-ease)*[-18,14,-12][i]).toFixed(2)}deg)`;
        layer.style.opacity = String(.35 + .65 * p);
      });
    } else if (index === 2) {
      const r = Math.min(2, Math.floor(local * 3));
      if (r !== room) setGallery('room', r);
    } else {
      const r = Math.min(3, Math.floor(local * 4));
      if (r !== rank) setGallery('rank', r);
    }
  }
  // IntersectionObserver limits the fallback to sections near the viewport.
  // One rAF per scroll burst; no permanent animation loop or wheel handlers.
  function paint() {
    frame = 0;
    if (document.hidden) return;
    const geometry = !nativeScroll && !reduced.matches ? [...reveals].map(el => [el, el.getBoundingClientRect()]) : [];
    if (!nativeScroll && !reduced.matches) for (const [el, box] of geometry) {
      const progress = clamp((innerHeight - box.top) / Math.min(box.height * .85, innerHeight * .6));
      el.style.opacity = String(.15 + progress * .85);
      el.style.transform = `translateY(${((1-progress)*45).toFixed(2)}px)`;
    }
    paintWorld();
    // Keep the compact platform navigation useful only around these chapters.
    const iphone = document.querySelector('#iphone').getBoundingClientRect();
    const links = document.querySelectorAll('.platform-nav a');
    links[0].setAttribute('aria-current', String(iphone.top > innerHeight * .45));
    links[1].setAttribute('aria-current', String(iphone.top <= innerHeight * .45));
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(paint); }
  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => entry.isIntersecting ? reveals.add(entry.target) : reveals.delete(entry.target));
    schedule();
  }, {rootMargin: '100px'});
  if (!nativeScroll) document.querySelectorAll('.reveal').forEach(el => revealObserver.observe(el));
  new IntersectionObserver(entries => { worldVisible = entries[0].isIntersecting; schedule(); }, {threshold: 0}).observe(world);
  new IntersectionObserver(entries => { mascotVisible = entries[0].isIntersecting; sprite(); }, {threshold: .1}).observe(moodArt);
  world.querySelectorAll('[data-world]').forEach(button => button.addEventListener('click', () => go(Number(button.dataset.world))));
  world.querySelectorAll('[data-world-mood]').forEach(button => button.addEventListener('click', () => {
    const i = moods.indexOf(button.dataset.worldMood); lastMood = i; setMood(i); go(0, (i + .3) / 5);
  }));
  for (const type of ['room','rank']) world.querySelectorAll(`[data-${type}-select]`).forEach(button => button.addEventListener('click', () => {
    const i = Number(button.dataset[type + 'Select']);
    setGallery(type, i);
    if (pinned()) go(type === 'room' ? 2 : 3, (i + .25) / (type === 'room' ? 3 : 4));
    else world.querySelector(`[data-${type}="${i}"]`).scrollIntoView({behavior: 'instant', block: 'center'});
  }));
  function preferences() {
    document.documentElement.classList.toggle('world-ready', pinned());
    setChapter(Math.max(0, chapter)); setGallery('room', Math.max(0, room)); setGallery('rank', Math.max(0, rank));
    if (reduced.matches) document.querySelectorAll('.reveal').forEach(el => { el.style.opacity = ''; el.style.transform = ''; });
    lastMood = -1; sprite(); schedule();
  }
  document.addEventListener('clockin-language', () => { setMood(moods.indexOf(mood)); schedule(); renderLive(); });
  window.addEventListener('scroll', schedule, {passive: true});
  window.addEventListener('resize', schedule);
  reduced.addEventListener('change', () => { preferences(); liveLoop(); });
  tall.addEventListener('change', preferences);

  // A monotonic foreground-only example. No storage, no calls to the relay.
  const live = document.querySelector('#live-demo');
  const pause = document.querySelector('#live-pause');
  const finish = document.querySelector('#live-stop');
  let liveVisible = false, livePaused = false, liveEnded = false, seconds = 5040;
  let tick = 0, began = 0, explicitPlay = false;
  function liveValue() { return seconds + (began ? (performance.now() - began) / 1000 : 0); }
  function renderLive() {
    const value = liveValue(), whole = Math.floor(value);
    live.querySelectorAll('.live-money').forEach(el => { el.textContent = ClockinLocale.money(value / 12); });
    live.querySelectorAll('.island-time').forEach(el => { el.textContent = [Math.floor(whole / 3600), Math.floor(whole / 60) % 60, whole % 60].map(n => String(n).padStart(2, '0')).join(':'); });
    const held = livePaused || (reduced.matches && !explicitPlay);
    live.querySelector('.live-status').textContent = t(liveEnded ? 'liveFinished' : held ? 'livePaused' : 'liveRunning');
    pause.textContent = t(held ? 'liveResume' : 'livePause');
    pause.disabled = liveEnded;
    finish.textContent = t(liveEnded ? 'liveRestart' : 'liveStop');
    document.querySelector('#live-feedback').textContent = liveEnded ? t('liveEndNote') : '';
  }
  function liveLoop() {
    if (began) seconds = liveValue();
    began = 0; clearInterval(tick); tick = 0;
    if (liveVisible && !document.hidden && !livePaused && !liveEnded && (!reduced.matches || explicitPlay)) {
      began = performance.now(); tick = setInterval(renderLive, 1000);
    }
    renderLive();
  }
  pause.addEventListener('click', () => {
    if (reduced.matches && !explicitPlay) { explicitPlay = true; livePaused = false; }
    else livePaused = !livePaused;
    liveLoop();
  });
  finish.addEventListener('click', () => {
    if (liveEnded) { seconds = 5040; liveEnded = false; livePaused = false; explicitPlay = true; }
    else liveEnded = true;
    liveLoop();
  });
  new IntersectionObserver(entries => { liveVisible = entries[0].isIntersecting; liveLoop(); }, {threshold: .15}).observe(live);
  document.addEventListener('visibilitychange', () => { sprite(); liveLoop(); schedule(); });
  preferences(); setMood(0); liveLoop();
})();
