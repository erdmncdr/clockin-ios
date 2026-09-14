'use strict';
(() => {
  const section=document.querySelector('.journey');
  const sticky=section.querySelector('.journey-sticky');
  const copy=section.querySelector('.journey-copy');
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  const toggle=document.querySelector('#demo-toggle');
  const panel=document.querySelector('.demo-window');
  const timerPanel=document.querySelector('#demo-timer-panel');
  const summary=document.querySelector('#demo-summary');
  const mascot=document.querySelector('#journey-mascot');
  const nav=[...section.querySelectorAll('[data-journey]')];
  const t=key=>ClockinLocale.t(key);
  const scenes=['work','break','reward'];
  const frames={work:[1,2,3,4].map(n=>`assets/companion/frame${n}.png`),break:[1,2,3,4].map(n=>`assets/companion/coffee${n}.png`),reward:['assets/companion/celebrate.png']};
  const icons={play:'<path d="m9 5 10 7-10 7Z"/>',pause:'<path d="M8 5v14M16 5v14"/>',coffee:'<path d="M5 8h11v7a5.5 5.5 0 0 1-11 0V8Zm11 1h2a3 3 0 0 1 0 6h-2M4 21h14M8 3v2m5-2v2"/>',arrow:'<path d="M6 18 18 6M6 6h12v12"/>',spark:'<path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4Z"/>'};
  const icon=name=>`<svg class="control-icon" viewBox="0 0 24 24" aria-hidden="true">${icons[name]}</svg>`;
  let active=-1,inView=false,motionPaused=reduced.matches,raf=0,frame=0,spriteTimer;
  let elapsed=0,running=false,started=0,timerTick,breakSeeded=false;
  const seconds=()=>elapsed+(running?(performance.now()-started)/1000:0);
  const state=()=>running?'running':elapsed>0?'paused':'ready';
  const mood=()=>active===2?'reward':state()==='paused'?'break':'work';
  function paintTimer(){
    const value=seconds(),whole=Math.floor(value);
    document.querySelector('#demo-time').textContent=[Math.floor(whole/3600),Math.floor(whole/60)%60,whole%60].map(n=>String(n).padStart(2,'0')).join(':');
    document.querySelector('#demo-money').textContent=ClockinLocale.money(value/12);
    document.querySelector('.timer-track').style.strokeDashoffset=motionPaused?'0':String(-whole%692);
  }
  function timerLoop(){
    clearInterval(timerTick);
    if(running&&inView&&!document.hidden)timerTick=setInterval(paintTimer,1000);
  }
  function sprites(){
    clearInterval(spriteTimer);
    mascot.src=frames[mood()][frame%frames[mood()].length];
    mascot.alt=t(mood()+'Alt');
    if(inView&&!motionPaused&&!document.hidden)spriteTimer=setInterval(()=>{
      const current=frames[mood()];mascot.src=current[++frame%current.length];
    },280);
  }
  function renderState(){
    panel.dataset.state=active===2?'summary':state();
    toggle.innerHTML=`<span>${t(running?'pause':elapsed>0?'resume':'start')}</span>${icon(running?'pause':'play')}`;
    document.querySelector('#demo-status').textContent=t(state());
    const speech=active===2?'rewardSpeech':running?(active===1?'resumeSpeech':'runningSpeech'):elapsed>0?'breakSpeech':'workSpeech';
    document.querySelector('#journey-speech').textContent=t(speech);
    const note=active===2?'reward':state()==='paused'?'break':'work';
    document.querySelector('#floating-note').innerHTML=icon(note==='reward'?'spark':note==='break'?'coffee':'arrow')+`<span>${t(note+'Note')}</span>`;
    paintTimer();sprites();
  }
  function setRunning(value){
    if(running&&!value)elapsed=seconds();
    if(!running&&value)started=performance.now();
    running=value;frame=0;
    renderState();timerLoop();
  }
  function translateScene(){
    const name=scenes[Math.max(active,0)];
    document.querySelector('#day-moment').textContent=t(name+'Time');
    document.querySelector('#journey-title').innerHTML=t(name+'Title');
    document.querySelector('#journey-description').textContent=t(name+'Description');
    renderState();
  }
  function show(index){
    if(index===active)return;
    active=index;frame=0;
    section.dataset.scene=scenes[index];
    // A break demonstrates a completed hour. Preserve the sample session on later visits.
    if(index>0)setRunning(false);
    if(index===1&&!breakSeeded){elapsed=Math.max(3600,elapsed);breakSeeded=true;}
    timerPanel.hidden=index===2;summary.hidden=index!==2;
    nav.forEach((button,i)=>{if(i===index)button.setAttribute('aria-current','step');else button.removeAttribute('aria-current');});
    translateScene();
    copy.classList.remove('scene-enter');
    requestAnimationFrame(()=>copy.classList.add('scene-enter'));
  }
  function update(){
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
  document.addEventListener('clockin-language',()=>{translateScene();schedule();});
  document.addEventListener('clockin-motion',event=>{motionPaused=event.detail.paused||reduced.matches;sprites();paintTimer();});
  document.addEventListener('visibilitychange',()=>{sprites();timerLoop();paintTimer();});
  window.addEventListener('scroll',schedule,{passive:true});
  window.addEventListener('resize',schedule);
  new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;sprites();timerLoop();if(inView){paintTimer();schedule();}},{threshold:0}).observe(section);
  update();
})();
