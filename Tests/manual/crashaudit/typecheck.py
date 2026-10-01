#!/usr/bin/env python3
"""Xcodebuild olmadan SDK denetimi; macro sinirlari acik test ikameleri kullanir."""
import json, pathlib, subprocess, tempfile, os, re
root = pathlib.Path(__file__).resolve().parents[3]
os.chdir(root)
work = pathlib.Path(tempfile.mkdtemp(prefix='clockin24-sdk-'))
obj = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', 'Clockin.xcodeproj/project.pbxproj']))['objects']
palette = pathlib.Path('Shared/Theme/PaletteEnvironment.swift').read_text().replace(
    '@Entry var palette: ClockinPalette = ClockinThemeChoice.carbon.palette',
    'var palette: ClockinPalette { get { self[AuditPaletteKey.self] } set { self[AuditPaletteKey.self] = newValue } }')
palette += '\nprivate struct AuditPaletteKey: EnvironmentKey { static let defaultValue = ClockinThemeChoice.carbon.palette }\n'
(work/'PaletteEnvironment.swift').write_text(palette + '\ntypealias AuditState<Value> = SwiftUI.State<Value>\n')
language = pathlib.Path('Clockin/Views/LanguageSwitch.swift').read_text().replace('@MainActor @Observable', '@MainActor')
(work/'LanguageSwitch.swift').write_text(language)
sparkle = os.environ.get('SPARKLE_FRAMEWORK_DIR')
if not sparkle:
    matches = list((pathlib.Path.home()/'Library/Developer/Xcode/DerivedData').glob('Clockin-*/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework'))
    if matches: sparkle = str(matches[0].parent)
failed = False
for key, target in obj.items():
    if target.get('isa') != 'PBXNativeTarget': continue
    name = target['name']; files=[]
    for g in target.get('fileSystemSynchronizedGroups', []):
        group=obj[g]; directory=pathlib.Path(group['path']); excluded=set()
        for e in group.get('exceptions', []):
            exception=obj[e]
            if exception.get('target') == key: excluded.update(exception.get('membershipExceptions', []))
        files += [str(f) for f in directory.rglob('*.swift') if str(f.relative_to(directory)) not in excluded]
    files = [str(work/pathlib.Path(f).name) if f in ['Shared/Theme/PaletteEnvironment.swift','Clockin/Views/LanguageSwitch.swift'] else f for f in files]
    # SDK 27 State macro'su da sunar. Ayni acik property-wrapper tipi,
    # takma adla bu kisitli ortamdaki macro alt surecine ihtiyac duymaz.
    resolved=[]
    for file in files:
        text=pathlib.Path(file).read_text()
        if re.search(r'@State\b', text):
            replacement=work/(file.replace('/', '_')+'.swift')
            replacement.write_text(re.sub(r'@State\b', '@AuditState', text))
            resolved.append(str(replacement))
        else: resolved.append(file)
    files=resolved
    ismac='Mac' in name
    sdk='macosx' if ismac else 'iphonesimulator'
    triples=['arm64-apple-macosx14.0','arm64-apple-macosx15.0'] if ismac else ['arm64-apple-ios17.0-simulator']
    for triple in triples:
        args=['xcrun','--sdk',sdk,'swiftc','-swift-version','6','-strict-concurrency=complete','-warnings-as-errors',
              '-module-cache-path','/tmp/clockin24-sdk-cache','-sdk',subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip(),
              '-target',triple,'-typecheck','-module-name',name]
        if 'Widgets' in name: args += ['-D','WIDGET_EXTENSION']
        if name=='ClockinMac':
            if not sparkle: raise SystemExit('Set SPARKLE_FRAMEWORK_DIR to an existing local framework (no download).')
            args += ['-F',sparkle]
        log=work/f'{name}-{triple}.log'
        with log.open('w') as output: result=subprocess.run(args+files,stdout=output,stderr=subprocess.STDOUT)
        print(f'{"PASS" if result.returncode == 0 else "FAIL"} {name}: {triple}; macro boundary substitutes; {log}',flush=True)
        if result.returncode:
            print(log.read_text()[:14000]); failed=True
print(f'Logs: {work}')
raise SystemExit(1 if failed else 0)
