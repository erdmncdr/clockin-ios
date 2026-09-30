'use strict';
// Mascot motion engine, shared by the hero and the workday demo.
//
// The drawings give the mascot its poses; everything that moves through space
// is animated by the compositor instead, so it is smooth at the display's
// refresh rate rather than stepping in 6-px frames:
// - drawn events (blink, antenna dip, glow, key presses, a sip of coffee) are
//   short clips from assets/companion/clips.json, picked at random intervals so
//   the mascot never repeats a fixed loop;
// - hops use squash and stretch on a wrapper, with a ground shadow that shrinks
//   as the mascot leaves the floor;
// - standing moods sway gently; the hero leans toward the pointer.
// Frames that bake a hop into the pixels are never shown; transforms do that now.
const ClockinSprite = (() => {
  const sequences = {
    working: [['t01.png', 160], ['t02.png', 140], ['t03.png', 150], ['t04.png', 140], ['t05.png', 160], ['t06.png', 150], ['t07.png', 150], ['t08.png', 100], ['t09.png', 100], ['t10.png', 140], ['t11.png', 160], ['t12.png', 140], ['t13.png', 170], ['t14.png', 190]].map(([file, ms]) => ({src: 'assets/companion/typing/' + file, ms})),
    coffee: [['c01.png', 260], ['c02.png', 220], ['c03.png', 220], ['c04.png', 110], ['c05.png', 220], ['c06.png', 340], ['c07.png', 300], ['c08.png', 300], ['c09.png', 540], ['c10.png', 330], ['c11.png', 330], ['c12.png', 380], ['c13.png', 320]].map(([file, ms]) => ({src: 'assets/companion/coffee-loop/' + file, ms})),
    celebrate: [['e01.png', 200], ['e02.png', 160], ['e03.png', 160], ['e04.png', 160], ['e05.png', 160], ['e06.png', 160], ['e07.png', 160], ['e08.png', 160], ['e09.png', 160], ['e10.png', 160], ['e11.png', 160], ['e12.png', 160], ['e13.png', 160], ['e14.png', 160], ['e15.png', 160], ['e16.png', 120]].map(([file, ms]) => ({src: 'assets/companion/celebrate-loop/' + file, ms})),
    hello: [['h01.png', 240], ['h02.png', 120], ['h03.png', 110], ['h04.png', 130], ['h05.png', 110], ['h06.png', 150], ['h07.png', 200], ['h08.png', 200], ['h09.png', 240], ['h10.png', 100], ['h11.png', 90], ['h12.png', 260], ['h13.png', 120], ['h14.png', 110], ['h15.png', 130], ['h16.png', 110]].map(([file, ms]) => ({src: 'assets/companion/hello-loop/' + file, ms}))
  };
  const cache = new Map();
  // Each frame is decoded off the main thread before its first use, and the
  // decoded Image is kept, so a frame change is a texture swap, not a decode
  // in the middle of a scroll.
  function preload(srcs) {
    for (const src of srcs) {
      if (cache.has(src)) continue;
      const img = new Image();
      img.decoding = 'async';
      img.src = src;
      const entry = {ready: false};
      cache.set(src, entry);
      (img.decode ? img.decode() : Promise.resolve()).then(() => { entry.ready = true; }, () => { entry.ready = true; });
      entry.img = img;
    }
  }
  const ready = src => cache.get(src)?.ready !== false;

  // AVIF frames are about a fifth of the PNGs. Support is probed once with a
  // 1-pixel image; until then the page shows its <picture> fallback frame.
  const avif = new Promise(resolve => {
    const probe = new Image();
    probe.onload = () => resolve(probe.width === 1);
    probe.onerror = () => resolve(false);
    probe.src = 'data:image/avif;base64,AAAAGGZ0eXBhdmlmAAAAAGF2aWZtaWYxAAAB4W1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAHBpY3QAAAAAAAAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAAADnBpdG0AAAAAAAEAAAA4aWluZgAAAAAAAgAAABVpbmZlAgAAAAABAABhdjAxAAAAABVpbmZlAgAAAQACAABhdjAxAAAAABppcmVmAAAAAAAAAA5hdXhsAAIAAQABAAABBGlwcnAAAADZaXBjbwAAABNjb2xybmNseAACAAIABoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAAAAAAAAACAAAAAgAAAChjbGFwAAAAAQAAAAEAAAABAAAAAf/AAAAAgAAA/8AAAACAAAAAAAAJaXJvdAAAAAAQcGl4aQAAAAADCAgIAAAADnBpeGkAAAAAAQgAAAA3YXV4QwAAAAB1cm46bXBlZzpoZXZjOjIwMTU6YXV4aWQ6MQAAAAAMAAAACE4BpQQAAf5AAAAADGF2MUOBAAwAAAAADGF2MUOBABwAAAAAI2lwbWEAAAAAAAAAAgABB4ECAwaJhIUAAgYDB4iKhIUAAAAsaWxvYwAAAABEAAACAAEAAAABAAACCQAAACAAAgAAAAEAAAIpAAAAJQAAAAFtZGF0AAAAAAAAAFUSAAoMAAAAAAZ//AgQEDQgMg4QAb4ASSSSIAEI4JuUVRIACggAAAAABn/8FTIXEAGOACCKCtLvWK23+kWAjE7E5r/wSp4=';
  });
  const manifest = fetch('assets/companion/clips.json').then(r => r.ok ? r.json() : null).catch(() => null);

  const ease = {out: 'cubic-bezier(.22,1,.36,1)', inOut: 'cubic-bezier(.65,0,.35,1)'};
  const random = (min, max) => min + Math.random() * (max - min);
  const wait = (ms, signal) => new Promise(resolve => {
    const id = setTimeout(resolve, ms);
    signal.addEventListener('abort', () => { clearTimeout(id); resolve(); }, {once: true});
  });

  // Which drawn events each mood may play, and how often. `hop` is not a clip:
  // it is the transform below.
  const weights = {
    hello: {blink: 3, antennaDip: 2, glow: 1.5, blinkAntennaDip: 1, glowAntennaDip: 1, hop: 2.4},
    celebrate: {hipLeft: 2, hipRight: 2, blink: 2, antennaDip: 1.5, glow: 1, blinkAntennaDip: 1, hop: 3},
    coffee: {steam: 3, blink: 2, antennaDip: 1.5, action: 2.5, actionAntennaDip: 1},
    working: {keyPress: 4, antennaDipTyping: 1.5, blink: 2, blinkAntennaDip: 1, antennaDip: 1}
  };
  const standing = {hello: true, celebrate: true};
  function pick(options, last) {
    const entries = Object.entries(options).filter(([name]) => name !== last);
    let roll = Math.random() * entries.reduce((sum, [, w]) => sum + w, 0);
    for (const [name, w] of entries) { roll -= w; if (roll <= 0) return name; }
    return entries[entries.length - 1][0];
  }

  // One hop: anticipation squash, stretched rise, hang, fall, landing squash
  // and a small settle. Heights are a share of the mascot's own size.
  function hop(body, shadow, height = 1) {
    // About 6% of its height: higher, and the hero mascot rose into its speech bubble.
    const h = 6.5 * height;
    const frames = [
      {offset: 0, transform: 'translateY(0) scale(1,1)'},
      {offset: .16, transform: 'translateY(1.2%) scale(1.07,.9)', easing: 'cubic-bezier(.3,0,.2,1)'},
      {offset: .46, transform: `translateY(-${h}%) scale(.95,1.07)`, easing: 'cubic-bezier(.15,.7,.35,1)'},
      {offset: .56, transform: `translateY(-${h * 1.08}%) scale(1,1)`, easing: 'cubic-bezier(.55,0,.85,.35)'},
      {offset: .8, transform: 'translateY(1%) scale(1.09,.88)', easing: 'cubic-bezier(.2,.9,.3,1)'},
      {offset: .9, transform: 'translateY(0) scale(.98,1.03)', easing: ease.out},
      {offset: 1, transform: 'translateY(0) scale(1,1)'}
    ];
    const animation = body.animate(frames, {duration: 820 + 120 * height});
    shadow?.animate([
      {offset: 0, transform: 'scale(1)', opacity: 1},
      {offset: .16, transform: 'scale(1.12,1)', opacity: 1},
      {offset: .5, transform: 'scale(.55)', opacity: .35},
      {offset: .8, transform: 'scale(1.18,1)', opacity: 1},
      {offset: 1, transform: 'scale(1)', opacity: 1}
    ], {duration: 820 + 120 * height, easing: 'linear'});
    return animation.finished.catch(() => {});
  }

  // Plays a mood on an <img>. Returns a stop function with `react()` (a hop,
  // for taps) attached.
  //   parts: {body, sway, shadow} wrapper elements for compositor motion
  //   small: use the 314 px frames made for the 150 px demo mascot
  function play(image, name, moving, {small = false, body = null, sway = null, shadow = null} = {}) {
    const controller = new AbortController();
    const {signal} = controller;
    let reactHop = () => {};
    let swayAnimation = null;

    (async () => {
      const [useAvif, clips] = await Promise.all([avif, manifest]);
      if (signal.aborted) return;
      // A <picture> source would override every later src change.
      if (image.parentElement?.tagName === 'PICTURE') image.parentElement.querySelectorAll('source').forEach(el => el.remove());
      const set = clips?.[name];
      const folder = set ? `assets/companion/${set.folder}/` : null;
      const url = id => folder + id + (useAvif ? (small ? '-314.avif' : '.avif') : '.png');
      const fallback = (sequences[name] || sequences.hello).map(step => ({src: useAvif ? step.src.replace(/\.png$/, small ? '-314.avif' : '.avif') : step.src, ms: step.ms}));

      let current = '';
      const show = src => { if (src !== current) { image.src = src; current = src; } };
      // Plays frames in order, holding a frame until the next one has decoded.
      async function run(steps) {
        preload(steps.map(s => s.src));
        for (const step of steps) {
          while (!ready(step.src) && !signal.aborted) await wait(30, signal);
          if (signal.aborted) return;
          show(step.src);
          if (step.ms) await wait(step.ms, signal);
        }
      }

      if (!set) {
        show(fallback[0].src);
        if (!moving) return;
        while (!signal.aborted) await run(fallback);
        return;
      }

      const rest = url(set.rest);
      show(rest);
      if (!moving) { preload([rest]); return; }
      const clip = key => set.clips[key].map(([id, ms]) => ({src: url(id), ms}));
      preload([rest, ...Object.keys(set.clips).flatMap(key => clip(key).map(s => s.src))]);

      if (standing[name] && sway && !signal.aborted) {
        // Starts and ends at rest, so switching moods never jumps mid-sway.
        swayAnimation = sway.animate([
          {offset: 0, transform: 'none'},
          {offset: .25, transform: 'translateY(-.5%) rotate(-.8deg)'},
          {offset: .5, transform: 'translateY(-1.1%) rotate(0deg)'},
          {offset: .75, transform: 'translateY(-.5%) rotate(.8deg)'},
          {offset: 1, transform: 'none'}
        ], {duration: 5200, iterations: Infinity, easing: 'linear'});
      }
      let hopping = false;
      reactHop = () => {
        if (!body || hopping || signal.aborted) return;
        hopping = true;
        hop(body, shadow, 1.15).then(() => { hopping = false; });
      };

      let last = '';
      const options = weights[name] || {};
      while (!signal.aborted) {
        if (set.clips.base) await run(clip('base'));
        else await wait(random(700, 2100), signal);
        if (signal.aborted) return;
        // Coffee and typing keep their base cycle and add an event only now and then.
        if (set.clips.base && Math.random() < .45) continue;
        const next = pick(Object.fromEntries(Object.entries(options).filter(([key]) => key === 'hop' ? !!body : !!set.clips[key])), last);
        last = next;
        if (next === 'hop') { if (!hopping) { hopping = true; await hop(body, shadow, random(.8, 1.1)); hopping = false; } }
        else await run(clip(next));
      }
    })();

    const stop = () => {
      controller.abort();
      if (swayAnimation && sway) {
        // Ease back to rest from wherever the sway is, instead of snapping.
        const from = getComputedStyle(sway).transform;
        swayAnimation.cancel();
        if (from && from !== 'none') sway.animate([{transform: from}, {transform: 'none'}], {duration: 520, easing: ease.out});
      }
    };
    stop.react = () => reactHop();
    return stop;
  }

  return {play, sequences};
})();
