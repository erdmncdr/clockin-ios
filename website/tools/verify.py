#!/usr/bin/env python3
"""Dependency-free static contract checks and uncompressed payload accounting."""
import collections, hashlib, json, pathlib, re, struct, subprocess
from html.parser import HTMLParser
ROOT=pathlib.Path(__file__).resolve().parents[1]; DIST=ROOT/'dist'
class Page(HTMLParser):
 def __init__(self): super().__init__(); self.nodes=[]
 def handle_starttag(self,tag,attrs): self.nodes.append((tag,dict(attrs)))
p=Page();p.feed((DIST/'index.html').read_text());nodes=p.nodes
text=(DIST/'locale.js').read_text();translations=json.loads(text[text.index('{'):text.index('\n};')+2])
assert translations['en'].keys()==translations['tr'].keys(), 'Locale keys differ'
keys={v for _,a in nodes for k,v in a.items() if k.startswith('data-i18n')}
for lang in ['en','tr']:
 assert not keys-translations[lang].keys(), (lang, keys-translations[lang].keys())
ids=[a['id'] for _,a in nodes if 'id' in a]; assert len(ids)==len(set(ids)), 'Duplicate IDs'
refs=set()
for tag,a in nodes:
 for attr in ['src','href']:
  ref=a.get(attr,'')
  if ref.startswith('#'): assert not ref[1:] or ref[1:] in ids,ref
  elif ref and not re.match(r'^(https?:|/)',ref): refs.add(ref)
 for ref in a.get('srcset','').split(','):
  if ref.strip(): refs.add(ref.strip().split()[0])
 if tag=='img': assert 'alt' in a and 'width' in a and 'height' in a,a
for ref in refs: assert (DIST/ref).is_file(),ref
assert not (DIST/'privacy').exists(), 'Privacy belongs to deploy relay'
D='https://github.com/ismailakdag/clockin/releases/download/macos-updates/Clockin.dmg'
assert all(a.get('href')==D for _,a in nodes if 'data-download' in a)
assert sum(a.get('href')=='https://testflight.apple.com/join/tr6kSDMN' for _,a in nodes)==3
clips=json.loads((DIST/'assets/companion/clips.json').read_text())
assert json.loads((DIST/'assets/companion/clips.js').read_text().split(' = ',1)[1].strip().rstrip(';'))==clips
sprite_refs=set()
for mood,s in clips.items():
 frames={s['rest']}|{frame for steps in s['clips'].values() for frame,_ in steps}
 for frame in frames:
  for suffix in (['.png'] if s.get('format')=='png' else ['.png','.avif'] + (['-314.avif'] if mood != 'hello' else [])):
   path=(DIST/'assets/companion'/s['folder']/(frame+suffix)).resolve();assert path.is_file(),path
   sprite_refs.add(path)
for path in DIST.glob('*.js'):subprocess.run(['node','--check',str(path)],check=True)
manifest=json.loads((DIST/'assets/gallery/manifest.json').read_text())
for f in manifest['files']:
 path=ROOT/f['file'];assert path.stat().st_size==f['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==f['sha256'],f['file']
for tag,a in nodes:
 if tag=='img' and a.get('src','').endswith('.png'):
  b=(DIST/a['src']).read_bytes();w,h=struct.unpack('>II',b[16:24])
  # CSS display dimensions may differ; their aspect ratio must be truthful.
  assert abs(w/h-int(a['width'])/int(a['height']))<.005,(a['src'],w,h,a['width'],a['height'])
code=sum(p.stat().st_size for p in DIST.iterdir() if p.suffix in ['.html','.css','.js'] and p.name not in ['features.css'])+(DIST/'assets/companion/clips.js').stat().st_size
png_refs={DIST/a['src'] for tag,a in nodes if tag=='img'}
# Upper bound: all image fallbacks at original resolution and every sprite pose,
# counted once (uncompressed HTTP payload; includes lazy/hidden assets).
all_png=png_refs|{p for p in sprite_refs if p.suffix=='.png'}
all_avif={p for p in sprite_refs if p.suffix=='.avif' and not p.stem.endswith('-314')}
base_without_sprite={p for p in png_refs if '/companion/' not in str(p) and p.name!='mascot-hello.png'}
summary={'localizedKeys':len(keys),'localReferences':len(refs),'galleryPNGs':len(manifest['files']),
 'galleryBytes':sum(f['bytes'] for f in manifest['files']),'htmlCssJsBytes':code,
 'initialHeroEstimateBytes':code+(DIST/'assets/clockin-icon-96.png').stat().st_size+sum((DIST/'assets/companion/hello-loop'/(frame+'.avif')).stat().st_size for frame in {clips['hello']['rest']}|{f for v in clips['hello']['clips'].values() for f,_ in v}),
 'allStaticImagesPlusAVIFClipsUpperBoundBytes':code+sum(p.stat().st_size for p in base_without_sprite|all_avif|{p for p in sprite_refs if '/gallery/' in str(p)}),
 'allPNGImagesAndClipsUpperBoundBytes':code+sum(p.stat().st_size for p in all_png),
 'distOnDiskBytes':sum(p.stat().st_size for p in DIST.rglob('*') if p.is_file())}
print(json.dumps(summary,indent=2));print('PASS: links, locale parity, sprite clips, PNG ratios, provenance, JS syntax, no dist/privacy')
