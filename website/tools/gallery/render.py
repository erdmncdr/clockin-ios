#!/usr/bin/env python3
"""Compile the app's artwork, render website PNGs, record SHA-256 provenance.
No app is launched, no user defaults/data are accessed. Requires macOS + Xcode.
Run from any directory: python3 website/tools/gallery/render.py
"""
import hashlib, json, pathlib, subprocess, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / 'website/dist/assets/gallery'
shared = ['Wardrobe.swift', 'WardrobeCatalog.swift', 'WardrobePalette.swift', 'WardrobeSkins.swift',
          'RoomArrangement.swift', 'RoomPlacement.swift', 'HomeSceneLayout.swift', 'MascotMotion.swift',
          'HeritageArt.swift', 'ArmorHD.swift', 'ArmorHDPixels.swift', 'ArmorHDParts.swift', 'ArmorHDCache.swift']
badges = ['ForgedCrown.swift', 'LevelPrestige.swift', 'PrestigeForge.swift', 'RankMaterial.swift', 'LevelPrestigeViews.swift', 'RankSignatures.swift']
inputs = [ROOT / 'Shared/Mascot' / f for f in shared] + [ROOT / 'Clockin/Celebrations' / f for f in badges]
art = ROOT / 'Shared/Mascot/WardrobeArt.swift'
with tempfile.TemporaryDirectory(prefix='clockin-gallery-') as tmp:
    tmp = pathlib.Path(tmp)
    # The drawing type is copied verbatim; the app's runtime cache actor is not needed.
    text = art.read_text()
    boundary = '// Actor icinde await yok;'
    assert text.count(boundary) == 1, 'WardrobeArt source boundary changed'
    (tmp/'WardrobeArt.swift').write_text(text.split(boundary)[0])
    (tmp/'Bundle.swift').write_text('import Foundation\nextension Bundle { static var app: Bundle { .main } }\n')
    binary = tmp/'render'
    subprocess.run(['/usr/bin/swiftc', '-O', '-swift-version', '6', '-module-cache-path', '/tmp/clockin-gallery-module-cache',
                    *map(str, inputs), str(tmp/'WardrobeArt.swift'), str(tmp/'Bundle.swift'),
                    str(ROOT/'website/tools/gallery/main.swift'), '-o', str(binary)], check=True)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(binary)], cwd=ROOT, check=True)
# Dedicated extension: preserve the original optimizer's manifest/provenance.
source_paths = inputs + [art, pathlib.Path(__file__), ROOT/'website/tools/gallery/main.swift']
for folder in ['Frames', 'Wardrobe', 'Home', 'Skins']:
    source_paths += sorted((ROOT/'Shared/Mascot'/folder).glob('*'))
manifest = {'generator': 'website/tools/gallery/render.py', 'format': 'PNG',
            'sources': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in source_paths if p.is_file()},
            'files': [{'file': str(p.relative_to(ROOT/'website')), 'bytes': p.stat().st_size,
                       'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                      for p in sorted(OUT.glob('*.png'))]}
(OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(f"Rendered {len(manifest['files'])} PNGs, {sum(f['bytes'] for f in manifest['files']):,} bytes")

clips = ROOT/'website/dist/assets/companion/clips.json'
(ROOT/'website/dist/assets/companion/clips.js').write_text('// Generated from clips.json by website/tools/gallery/render.py.\nwindow.ClockinClips = '+clips.read_text().strip()+';\n')
