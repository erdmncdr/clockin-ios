'use strict';
(() => {
  const section = document.querySelector('.journey');
  const sticky = section.querySelector('.journey-sticky');
  const copy = section.querySelector('.journey-copy');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const toggle = document.querySelector('#demo-toggle');
  const timerPanel = document.querySelector('#demo-timer-panel');
  const summary = document.querySelector('#demo-summary');
  const mascot = document.querySelector('#journey-mascot');
  const motion = section.querySelector('.motion-toggle');
  const nav = [...section.querySelectorAll('[data-journey]')];
  const scenes = [
    {name:'work', time:'09.00 / Yeni bir başlangıç', title:'Bir tık.<br> Ve odaktasın.', description:'İlk adımı sen at. Süreni ve emeğinin karşılığını Clockin takip etsin.', speech:'Hazırım. Hadi başlayalım.', note:'Kendi ritminde.', frames:[1,2,3,4].map(n=>`assets/companion/frame${n}.png`), alt:'Bilgisayarında çalışan Clockin maskotu'},
    {name:'break', time:'11.30 / Bir nefes arası', title:'Biraz da<br> kendine zaman.', description:'Kahven soğumasın. Mola ver, hazır olduğunda kaldığın yerden devam et.', speech:'Kahveler benden. Acelemiz yok.', note:'Mola da işin bir parçası.', frames:[1,2,3,4].map(n=>`assets/companion/coffee${n}.png`), alt:'Kahve molası veren Clockin maskotu'},
    {name:'reward', time:'13.40 / İyi iş çıkardın', title:'Emeğinin<br> karşılığı burada.', description:'Çalıştığın saatler, kazancın, küçük zaferlerin. Gününe dönüp bir bak.', speech:'Bak, bugün ne kadar yol aldın.', note:'Her seans bir adım.', frames:['assets/companion/celebrate.png'], alt:'İlerlemeni kutlayan Clockin maskotu'}
  ];
  let active=-1, inView=false, motionPaused=reduced.matches, raf=0, frame=0, spriteTimer;
  let elapsed=0, running=false, started=0, timerTick;
  const seconds = () => elapsed + (running ? (performance.now()-started)/1000 : 0);
  function paintTimer() {
    const value=seconds(), whole=Math.floor(value);
    document.querySelector('#demo-time').textContent=[Math.floor(whole/3600),Math.floor(whole/60)%60,whole%60].map(n=>String(n).padStart(2,'0')).join(':');
    document.querySelector('#demo-money').textContent=new Intl.NumberFormat('tr-TR',{style:'currency',currency:'TRY'}).format(value/12);
    document.querySelector('.timer-track').style.strokeDashoffset=motionPaused ? '0' : String(-whole%692);
  }
  function timerLoop() {
    clearInterval(timerTick);
    if(running && inView && !document.hidden) timerTick=setInterval(paintTimer,1000);
  }
  function setRunning(value) {
    if(running && !value) elapsed=seconds();
    if(!running && value) started=performance.now();
    running=value;
    toggle.innerHTML=running?'Mola ver <span aria-hidden="true">Ⅱ</span>':(elapsed>0?'Devam et':'Çalışmaya başla')+' <span aria-hidden="true">▶</span>';
    document.querySelector('#demo-status').textContent=running?'Odak zamanı':elapsed>0?'Moladasın':'Başlamaya hazır';
    paintTimer();timerLoop();
    if(active===0) document.querySelector('#journey-speech').textContent=running?'Tamam, zaman bende. Sen işine bak.':'Hazır olduğunda buradayım.';
    if(active===1) document.querySelector('#journey-speech').textContent=running?'Kaldığımız yerden devam.':'Kahveler benden. Acelemiz yok.';
  }
  function sprites() {
    clearInterval(spriteTimer);
    if(inView && !motionPaused && !document.hidden) spriteTimer=setInterval(()=>{
      const frames=scenes[Math.max(active,0)].frames;
      mascot.src=frames[++frame%frames.length];
    },280);
  }
  function show(index) {
    if(index===active)return;
    active=index;frame=0;const scene=scenes[index];
    section.dataset.scene=scene.name;
    document.querySelector('#day-moment').textContent=scene.time;
    document.querySelector('#journey-title').innerHTML=scene.title;
    document.querySelector('#journey-description').textContent=scene.description;
    document.querySelector('#journey-speech').textContent=scene.speech;
    document.querySelector('#floating-note').innerHTML='<span aria-hidden="true">'+(index===2?'✦':index===1?'☕':'↗')+'</span> '+scene.note;
    mascot.src=scene.frames[0];mascot.alt=scene.alt;
    // Leaving the work scene pauses the visitor's sample session; scrolling never starts it.
    if(index>0)setRunning(false);
    timerPanel.hidden=index===2;summary.hidden=index!==2;
    nav.forEach((button,i)=>{if(i===index)button.setAttribute('aria-current','step');else button.removeAttribute('aria-current');});
    copy.classList.remove('scene-enter');
    requestAnimationFrame(()=>copy.classList.add('scene-enter'));
    sprites();
  }
  function update() {
    raf=0;
    const rect=section.getBoundingClientRect();
    const distance=Math.max(1,rect.height-sticky.offsetHeight);
    const progress=Math.max(0,Math.min(1,-rect.top/distance));
    const index=Math.min(2,Math.floor(progress*3));
    section.style.setProperty('--journey-progress',String(progress));
    section.style.setProperty('--scene-progress',String(Math.min(1,progress*3-index)));
    show(index);
  }
  function schedule(){if(!raf)raf=requestAnimationFrame(update);}
  nav.forEach((button,index)=>button.addEventListener('click',()=>{
    const top=window.scrollY+section.getBoundingClientRect().top;
    const distance=section.offsetHeight-sticky.offsetHeight;
    window.scrollTo({top:top+distance*((index+.12)/3),behavior:motionPaused?'instant':'smooth'});
  }));
  toggle.addEventListener('click',()=>setRunning(!running));
  function setMotion(value){
    motionPaused=value || reduced.matches;
    motion.setAttribute('aria-pressed',String(motionPaused));
    motion.disabled=reduced.matches;
    motion.textContent=reduced.matches?'Hareket azaltıldı':motionPaused?'Hareketi aç':'Hareketi durdur';
    sprites();paintTimer();
  }
  motion.addEventListener('click',()=>document.dispatchEvent(new CustomEvent('clockin-toggle-motion')));
  document.addEventListener('clockin-motion',event=>setMotion(event.detail.paused));
  document.addEventListener('visibilitychange',()=>{sprites();timerLoop();paintTimer();});
  window.addEventListener('scroll',schedule,{passive:true});
  window.addEventListener('resize',schedule);
  new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;sprites();timerLoop();if(inView){paintTimer();schedule();}},{threshold:0}).observe(section);
  update();setMotion(document.documentElement.classList.contains('motion-paused'));
})();
