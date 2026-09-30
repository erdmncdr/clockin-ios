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
  const sprite={work:'working',break:'coffee',reward:'celebrate'};
  const icons={play:'<path d="m9 5 10 7-10 7Z"/>',pause:'<path d="M8 5v14M16 5v14"/>',coffee:'<path d="M5 8h11v7a5.5 5.5 0 0 1-11 0V8Zm11 1h2a3 3 0 0 1 0 6h-2M4 21h14M8 3v2m5-2v2"/>',arrow:'<path d="M6 18 18 6M6 6h12v12"/>',spark:'<path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4Z"/>'};
  const icon=name=>`<svg class="control-icon" viewBox="0 0 24 24" aria-hidden="true">${icons[name]}</svg>`;
  let active=-1,inView=false,motionPaused=reduced.matches,raf=0,stopSprite=()=>{},playing='';
  let elapsed=0,running=false,started=0,timerTick;
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
    const moving=inView&&!motionPaused&&!document.hidden;
    const key=mood()+(moving?':moving':':still');
    mascot.alt=t(mood()+'Alt');
    // Re-rendering the same state keeps the loop going instead of restarting it.
    if(key===playing)return;
    stopSprite();playing=key;
    stopSprite=ClockinSprite.play(mascot,sprite[mood()],moving,{small:true,body:mascot.closest('.mascot-body')});
  }
  function renderState(){
    panel.dataset.state=active===2?'summary':state();
    toggle.innerHTML=`<span>${t(running?'pause':elapsed>0?'resume':'start')}</span>${icon(running?'pause':'play')}`;
    document.querySelector('#demo-status').textContent=t(state());
    const speech=active===2?'rewardSpeech':running?(active===1?'resumeSpeech':'runningSpeech'):elapsed>0?'breakSpeech':'workSpeech';
    document.querySelector('#journey-speech').textContent=t(speech);
    paintTimer();sprites();
  }
  function setRunning(value){
    if(running&&!value)elapsed=seconds();
    if(!running&&value)started=performance.now();
    running=value;
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
    active=index;
    section.dataset.scene=scenes[index];
    // Each story scene starts a fresh example, in either scroll direction.
    // Scrolling within the same scene leaves its interactive timer untouched.
    running=false;
    started=0;
    elapsed=index===1?3600:0;
    timerLoop();
    // Both panels stay rendered and cross-fade; `inert` keeps the hidden one out
    // of focus and the accessibility tree.
    panel.dataset.view=index===2?'summary':'timer';
    for(const [el,on] of [[timerPanel,index!==2],[summary,index===2]]){el.toggleAttribute('inert',!on);el.setAttribute('aria-hidden',String(!on));}
    nav.forEach((button,i)=>{if(i===index)button.setAttribute('aria-current','step');else button.removeAttribute('aria-current');});
    translateScene();
    copy.classList.remove('scene-enter');
    requestAnimationFrame(()=>copy.classList.add('scene-enter'));
  }
  // Scroll work runs every frame, so it only writes transforms on the three
  // elements that move, and no custom property is set on the section: that
  // restyled its whole subtree. Geometry is read at the start of the frame,
  // before any write, so it never forces a layout; caching it went stale
  // whenever content above the section changed height after load.
  const orbit=section.querySelector('.journey-orbit');
  const bar=section.querySelector('.journey-progress>span');
  const phone=matchMedia('(max-width:650px)');
  let sectionTop=0,distance=1,lastProgress=-1;
  function measure(){
    sectionTop=section.offsetTop;
    distance=Math.max(1,section.offsetHeight-sticky.offsetHeight);
  }
  function update(){
    raf=0;
    measure();
    const progress=Math.max(0,Math.min(1,(window.scrollY-sectionTop)/distance));
    const index=Math.min(2,Math.floor(progress*3));
    if(progress!==lastProgress){
      lastProgress=progress;
      const scene=Math.min(1,progress*3-index);
      bar.style.transform=`scaleX(${progress.toFixed(4)})`;
      if(motionPaused){panel.style.transform='none';orbit.style.transform='translateY(-50%)';}
      else{
        panel.style.transform=phone.matches?`rotateY(${(-5+scene*7).toFixed(2)}deg)`:`rotateY(${(-9+scene*12).toFixed(2)}deg) rotateX(3deg)`;
        orbit.style.transform=`translateY(-50%) scale(${(.9+scene*.15).toFixed(4)})`;
      }
    }
    show(index);
  }
  function schedule(){if(!raf)raf=requestAnimationFrame(update);}
  nav.forEach((button,index)=>button.addEventListener('click',()=>{
    measure();
    window.scrollTo({top:sectionTop+distance*((index+.12)/3),behavior:motionPaused?'instant':'smooth'});
  }));
  toggle.addEventListener('click',()=>setRunning(!running));
  document.addEventListener('clockin-language',()=>{translateScene();schedule();});
  document.addEventListener('clockin-motion',event=>{motionPaused=event.detail.paused||reduced.matches;lastProgress=-1;schedule();sprites();paintTimer();});
  document.addEventListener('visibilitychange',()=>{sprites();timerLoop();paintTimer();});
  window.addEventListener('scroll',schedule,{passive:true});
  window.addEventListener('resize',()=>{lastProgress=-1;schedule();});
  phone.addEventListener('change',()=>{lastProgress=-1;schedule();});
  new IntersectionObserver(entries=>{inView=entries[0].isIntersecting;sprites();timerLoop();if(inView){paintTimer();schedule();}},{threshold:0}).observe(section);
  measure();
  update();
})();
