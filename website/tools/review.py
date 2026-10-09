#!/usr/bin/env python3
"""Make an offline browser review harness outside dist; no server/dependencies.
The iframe gets an exact viewport. CSS/JS are inlined from dist; image bytes are
unchanged. No production runtime hooks, networking or browser security overrides.
"""
import json, pathlib, re, argparse
root = pathlib.Path(__file__).resolve().parents[1]
a = argparse.ArgumentParser(); a.add_argument('--output', default='/tmp/clockin-review.html'); args=a.parse_args()
html=(root/'dist/index.html').read_text()
html=html.replace('<head>','<head><base href="'+(root/'dist').as_uri()+'/">')
html=re.sub(r'<link rel="stylesheet" href="([^"]+)">',lambda m:'<style>'+ (root/'dist'/m[1]).read_text()+'</style>',html)
scripts=[]
def script(m):
    code=(root/'dist'/m[1]).read_text()
    if m[1]=='preferences.js':return '<script>'+code+'</script>'
    scripts.append(code);return ''
html=re.sub(r'<script src="([^"]+)"[^>]*></script>',script,html)
bootstrap='window.reviewErrors=[];addEventListener("error",e=>{if(e.message)reviewErrors.push(e.message)});addEventListener("unhandledrejection",e=>reviewErrors.push(String(e.reason)));'
html=html.replace('</body>','<script>'+bootstrap+'</script>'+''.join('<script>'+s+'</script>' for s in scripts)+'</body>')
# JSON script data must not terminate the host's script tag.
data=json.dumps(html).replace('</','<\\/')
host='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Clockin local review</title>
<style>body{margin:0;background:#34353a;color:#fff;font:13px system-ui}header{position:sticky;top:0;padding:10px;background:#202126;z-index:3;display:flex;gap:8px;flex-wrap:wrap}button{padding:8px 12px;border:1px solid #62656d;border-radius:6px;background:#30333a;color:white;cursor:pointer}#view{margin:auto;transform-origin:top center}iframe{display:block;border:0;background:#08090b}#stage{overflow:hidden}pre{font:12px ui-monospace;white-space:pre-wrap;margin:15px;padding:15px;background:#181a1e}#size{padding:8px;color:#d4dfed}</style>
<header><button data-size="1440,900">1440 × 900</button><button data-size="1024,800">1024 × 800</button><button data-size="375,812">375 × 812</button><button id="lang">EN / TR</button><button id="theme">Light / dark</button><button data-go=".hero">Hero</button><button data-go=".journey">Workday</button><button data-go="#mac">Mac</button><button data-go=".live-showcase">iPhone</button><button data-go=".world">Companion</button><button data-go=".features">Promises</button><button id="test">Run browser checks</button><span id="size"></span></header>
<div id="stage"><div id="view"><iframe id="site" title="Clockin preview"></iframe></div></div><pre id="results">Ready. Set a viewport, inspect the page, then run checks. Nothing is deployed.</pre>
<script>
const f=document.querySelector('#site'), view=document.querySelector('#view'), result=document.querySelector('#results');
let w=1440,h=900;function fit(){const scale=Math.min(1,(innerWidth-16)/w,(innerHeight-75)/h);f.style.width=w+'px';f.style.height=h+'px';view.style.width=w+'px';view.style.height=h+'px';view.style.transform='scale('+scale+')';document.querySelector('#stage').style.height=h*scale+'px';document.querySelector('#size').textContent=w+' × '+h+' / scale '+scale.toFixed(2)}
document.querySelectorAll('[data-size]').forEach(b=>b.onclick=()=>{[w,h]=b.dataset.size.split(',').map(Number);fit()});addEventListener('resize',fit);fit();
const doc=()=>f.contentDocument, win=()=>f.contentWindow;
document.querySelector('#lang').onclick=()=>doc().querySelector('[data-language="'+(doc().documentElement.lang==='en'?'tr':'en')+'"]').click();
document.querySelector('#theme').onclick=()=>doc().querySelector('#theme-toggle').click();
document.querySelectorAll('[data-go]').forEach(b=>b.onclick=()=>doc().querySelector(b.dataset.go).scrollIntoView({behavior:'instant',block:'start'}));
const delay=ms=>new Promise(r=>setTimeout(r,ms));
document.querySelector('#test').onclick=async()=>{
 // Start each run from a fresh document so a previous explicit timer restart
 // cannot change the initial reduced-motion state of the next run.
 document.querySelector('#test').disabled=true;
 await new Promise(resolve=>{f.addEventListener('load',resolve,{once:true});f.srcdoc=page});
 await delay(100);
 const d=doc(),v=win(),checks=[],bad=[];const check=(name,value)=>{checks.push({name,pass:!!value});if(!value)bad.push(name)};
 const click=s=>d.querySelector(s).click();const text=s=>d.querySelector(s).textContent;
 const calm=v.matchMedia('(prefers-reduced-motion:reduce)').matches;
 const before={lang:d.documentElement.lang,theme:d.documentElement.dataset.theme,y:v.scrollY};
 for(const language of ['en','tr']){click('[data-language="'+language+'"]');for(const theme of ['light','dark']){
 if(d.documentElement.dataset.theme!==theme)click('#theme-toggle');
 for(const selector of ['.hero','.journey','#mac','#iphone','.world','.features','.closing']){
 d.querySelector(selector).scrollIntoView({behavior:'instant'});await delay(120);
 check(language+'/'+theme+'/'+selector+' no overflow',d.documentElement.scrollWidth<=v.innerWidth);
 }}}
 click('[data-language="'+before.lang+'"]');if(d.documentElement.dataset.theme!==before.theme)click('#theme-toggle');
 for(const screen of ['today','history','progress','settings']){click('[data-screen="'+screen+'"]');await delay(150);const image=d.querySelector('[data-image="'+screen+'"] img');check(screen+' screenshot selected',image.closest('figure').classList.contains('is-selected'));}
 d.querySelector('#live-demo').scrollIntoView({behavior:'instant'});await delay(300);
 if(calm)click('#live-pause');
 let a=text('.live-activity .live-money');await delay(1300);let b=text('.live-activity .live-money');check('live money counts up',a!==b);
 click('#live-pause');a=text('.live-activity .live-money');await delay(1200);check('pause freezes live money',a===text('.live-activity .live-money'));
 click('#live-stop');check('clock out ends sample',d.querySelector('#live-pause').disabled&&text('#live-feedback').length>0);
 click('#live-stop');check('restart enables sample',!d.querySelector('#live-pause').disabled);
 d.querySelector('.journey').scrollIntoView({behavior:'instant'});await delay(250);click('#demo-toggle');await delay(1150);check('workday timer starts',text('#demo-time')!=='00:00:00');click('#demo-toggle');a=text('#demo-time');await delay(1100);check('workday timer pauses',a===text('#demo-time'));
 if(!calm&&v.innerHeight>=650){
 d.querySelector('.world').scrollIntoView({behavior:'instant'});await delay(200);
 for(const i of [0,1,2,3,0]){click('[data-world="'+i+'"]');await delay(150);check('world chapter '+i+' visible',d.querySelector('[data-chapter="'+i+'"]').classList.contains('is-active')&&!d.querySelector('[data-chapter="'+i+'"]').inert)}
 for(const mood of ['tired','angry']){click('[data-world-mood="'+mood+'"]');await delay(350);check(mood+' correct asset',d.querySelector('#world-mascot').src.includes('/gallery/'+(mood==='tired'?'z':'a')))}
 click('[data-world="2"]');await delay(150);click('[data-room-select="2"]');await delay(150);check('studio selected',d.querySelector('[data-room="2"]').classList.contains('is-active'));
 click('[data-world="3"]');await delay(150);click('[data-rank-select="3"]');await delay(150);check('eternal selected',d.querySelector('[data-rank="3"]').classList.contains('is-active'));
 }else{check('reduced/short mode exposes all chapters',[...d.querySelectorAll('.world-panel')].every(p=>!p.inert&&v.getComputedStyle(p).opacity==='1'));}
 check('no runtime errors',v.reviewErrors.length===0);
 check('correct Mac download',[...d.querySelectorAll('[data-download]')].every(a=>a.href==='https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg'));
 check('public beta linked',d.querySelectorAll('a[href="https://testflight.apple.com/join/tr6kSDMN"]').length===3);
 check('loaded images decode',[...d.images].filter(i=>i.complete).every(i=>i.naturalWidth>0));
 v.scrollTo({top:before.y,behavior:'instant'});
 result.textContent=JSON.stringify({viewport:[v.innerWidth,v.innerHeight],reduced:calm,passed:checks.length-bad.length,total:checks.length,failed:bad,errors:v.reviewErrors,checks},null,2);result.scrollIntoView({behavior:'instant'});document.querySelector('#test').disabled=false;
};
const page=__PAGE__;f.srcdoc=page;
</script></html>'''
pathlib.Path(args.output).write_text(host.replace('__PAGE__',data))
print(args.output)
