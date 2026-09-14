'use strict';
(() => {
  const hero = document.querySelector('.companion');
  const image = document.querySelector('#companion-image');
  const speech = document.querySelector('#companion-speech');
  const pause = document.querySelector('#pause-companion');
  const tour = document.querySelector('#tour-guide');
  const guideImage = document.querySelector('#guide-image');
  const next = document.querySelector('#next-tour');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const moods = {
    hello: {frames:['assets/mascot-hello.png'], text:'Selam, ben Clockin.\nBugün birlikte çalışalım mı?'},
    working: {frames:[1,2,3,4].map(n => `assets/companion/frame${n}.png`), text:'Sen işine odaklan.\nZamanını ben takip ederim.'},
    coffee: {frames:[1,2,3,4].map(n => `assets/companion/coffee${n}.png`), text:'Bir kahve molası?\nDöndüğünde buradayım.'},
    celebrate: {frames:['assets/companion/celebrate.png'], text:'Her seans bir adım daha.\nİlerlemeni birlikte görelim.'}
  };
  const steps = [
    {screen:'timer', mood:'working', title:'Önce işe başlayalım.', text:'Bir tıkla sayacı başlat. Süren ve kazancın birlikte ilerlesin.'},
    {screen:'history', mood:'coffee', title:'Emeğinin karşılığını gör.', text:'Gün gün ne kadar çalıştığını ve kazandığını burada bulursun.'},
    {screen:'progress', mood:'celebrate', title:'Küçük adımlar birikir.', text:'Her çalışma seansıyla deneyim puanı kazan, seviyeni yükselt.'}
  ];
  let mood = 'hello', frame = 0, scene = 0, step = -1;
  let paused = reduced.matches, visible = true, guideVisible = false, tick = null, change = null;
  let override = false;
  const scenes = ['hello','working','coffee','celebrate'];
  const preloads = [];
  Object.values(moods).flatMap(m => m.frames).forEach(src => {const img = new Image(); img.src = src; preloads.push(img);});
  function paint() {
    const frames = moods[mood].frames;
    image.src = frames[frame % frames.length];
    if (step >= 0) guideImage.src = moods[steps[step].mood].frames[frame % moods[steps[step].mood].frames.length];
  }
  function timers() {
    clearInterval(tick); clearTimeout(change); tick = null; change = null;
    const moving = !paused && !reduced.matches && !document.hidden;
    hero.classList.toggle('is-paused', !moving);
    if (!moving) return;
    if (visible || (step >= 0 && guideVisible)) tick = setInterval(() => {frame++; paint();}, 280);
    if (visible && step < 0 && !override) change = setTimeout(() => {scene = (scene + 1) % scenes.length; setMood(scenes[scene]);}, 10000);
  }
  function setMood(name, text) {
    mood = name; frame = 0;
    hero.dataset.mood = name;
    speech.textContent = text || moods[name].text;
    paint(); timers();
  }
  function setPaused(value) {
    paused = reduced.matches || value;
    pause.disabled = reduced.matches;
    pause.setAttribute('aria-pressed', String(paused));
    pause.textContent = reduced.matches ? 'Hareket azaltıldı' : (paused ? 'Hareketi aç' : 'Hareketi durdur');
    timers();
  }
  function showStep(index, select = true) {
    step = index; const item = steps[index];
    tour.hidden = false;
    document.querySelector('#guide-title').textContent = item.title;
    document.querySelector('#guide-speech').textContent = item.text;
    next.innerHTML = index === steps.length - 1 ? 'Tamamdır <span aria-hidden="true">✓</span>' : 'Devam et <span aria-hidden="true">→</span>';
    guideImage.src = moods[item.mood].frames[0];
    if (select) document.querySelector(`[data-screen="${item.screen}"]`).click();
    setMood(item.mood);
  }
  function finishTour() {
    const screen = steps[Math.max(step,0)].screen;
    step = -1; tour.hidden = true;
    document.querySelector(`[data-screen="${screen}"]`).focus({preventScroll:true});
    setMood('hello','Ne zaman hazırsan,\nben buradayım.');
  }
  document.querySelector('#start-tour').addEventListener('click', () => {
    showStep(0);
    tour.scrollIntoView({behavior:reduced.matches ? 'instant' : 'smooth',block:'start'});
    next.focus({preventScroll:true});
  });
  next.addEventListener('click', () => step < steps.length - 1 ? showStep(step + 1) : finishTour());
  document.querySelector('#close-tour').addEventListener('click', finishTour);
  tour.addEventListener('keydown', event => {if(event.key === 'Escape') {event.preventDefault(); finishTour();}});
  document.querySelectorAll('[data-screen]').forEach(button => button.addEventListener('click', () => {
    if(step >= 0) showStep(steps.findIndex(s => s.screen === button.dataset.screen), false);
  }));
  document.querySelector('#meet-companion').addEventListener('click', () => {
    scene = (scene + 1) % scenes.length;
    setMood(scenes[scene]);
  });
  pause.addEventListener('click', () => setPaused(!paused));
  document.querySelectorAll('[data-download]').forEach(button => {
    const greet = () => {override = true; setMood('celebrate', DOWNLOAD_URL ? 'Mac’inde görüşürüz!' : 'Yakında Mac’inde\ngörüşmek üzere!');};
    const restore = () => {override = false; setMood(scenes[scene]);};
    button.addEventListener('pointerenter', event => {if(event.pointerType !== 'touch') greet();});
    button.addEventListener('pointerleave', restore);
    button.addEventListener('focus', greet);
    button.addEventListener('blur', restore);
  });
  new IntersectionObserver(entries => {visible = entries[0].isIntersecting; timers();}, {threshold:0.1}).observe(hero);
  new IntersectionObserver(entries => {guideVisible = entries[0].isIntersecting; timers();}, {threshold:0.1}).observe(tour);
  document.addEventListener('visibilitychange', timers);
  reduced.addEventListener('change', () => setPaused(reduced.matches));
  speech.style.whiteSpace = 'pre-line';
  setPaused(paused);
})();
