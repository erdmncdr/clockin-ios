#!/usr/bin/env python3
"""Compare active phone source against the task base, expanding only extracted views."""
from pathlib import Path
import argparse,difflib,re,subprocess,json
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--base', default='6546b420b3ee81f8bdf43c61daef4404b2b00ffd')
BASE = parser.parse_args().base
root=Path(__file__).resolve().parents[3]

def active_ios(source,debug=False):
    def condition(expr):
        for word,value in [('os(macOS)',False),('os(iOS)',True),('canImport(UIKit)',True),('DEBUG',debug),('WIDGET_EXTENSION',False)]:
            expr=expr.replace(word,str(value))
        expr=expr.replace('&&',' and ').replace('||',' or ').replace('!',' not ')
        return bool(eval(expr,{'__builtins__':{}},{}))
    stack=[];enabled=True;out=[]
    for line in source.splitlines():
        stripped=line.strip()
        if stripped.startswith('#if '):
            val=condition(stripped[4:]);stack.append((enabled,val));enabled=enabled and val
        elif stripped=='#else':
            parent,val=stack[-1];enabled=parent and not val
        elif stripped.startswith('#elseif '):
            parent,seen=stack[-1];val=not seen and condition(stripped[8:]);stack[-1]=(parent,seen or val);enabled=parent and val
        elif stripped=='#endif':
            parent,_=stack.pop();enabled=parent
        elif enabled:out.append(line)
    assert not stack
    return '\n'.join(out)

def remove_property(text,name):
    pattern=r'(?:    @ViewBuilder\n)?    private var '+name+r': [^{]+\{'
    m=re.search(pattern,text);assert m,name
    i=m.end();start=i;depth=1
    while depth:
        if text[i]=='{':depth+=1
        elif text[i]=='}':depth-=1
        i+=1
    return text[:m.start()]+text[i:],text[start:i-1]

def normalize(source,file,debug):
    s=active_ios(source,debug)
    if file.endswith('SettingsView.swift'):
        for name in ['settingsContent','helpSection','todaySection','appearanceSection','languageThemeSection','aboutSection']:
            if re.search(r'private var '+name+r'\b',s):
                s,body=remove_property(s,name)
                s=re.sub(r'(?m)^\s*'+name+r'\s*$',lambda _:body,s)
    if file.endswith('SettingsView.swift') and 'private func companionBehaviorPicker' in s:
        start=s.index('    private func companionBehaviorPicker')
        opening=s.index('{',start);i=opening+1;depth=1
        while depth:
            if s[i]=='{':depth+=1
            elif s[i]=='}':depth-=1
            i+=1
        body=s[opening+1:i-1]
        s=s[:start]+s[i:]
        s=s.replace('companionBehaviorPicker(hours: hours)',body)
    if file.endswith('EarningsChartView.swift') and 'private var inspectionDate:' in s:
        s,body=remove_property(s,'inspectionDate');assert body.strip()=='selectedDate'
        s=s.replace('let selectedDate = inspectionDate','let selectedDate')
    # These platform wrappers return self on iOS, as asserted below.
    for name in ['macTabBarClearance','macPageColumn','macSettingsField','macHoverFeedback']:
        if file.endswith('PlatformModifiers.swift'):
            m=re.search(r'    (?:@ViewBuilder\n    )?func '+name+r'\([^)]*\) -> some View \{\s*self\s*\}',s)
            if m:s=s[:m.start()]+s[m.end():]
        s=re.sub(r'\.'+name+r'\(\)', '', s)
    s=re.sub(r'\.macSheetFrame\([^)]*\)','',s)
    s=re.sub(r'(?m)^\s*//.*$','',s)
    return re.sub(r'\s+','',s)

files=subprocess.check_output(['git','diff','--name-only',BASE],cwd=root,text=True).splitlines()
files += subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
files = sorted(set(files))
failures=[];count=0
for file in files:
    if not file.endswith('.swift') or not file.startswith(('Clockin/','Shared/')):continue
    prior=subprocess.run(['git','show',f'{BASE}:{file}'],cwd=root,text=True,capture_output=True)
    old=prior.stdout if prior.returncode == 0 else ''
    new=(root/file).read_text()
    for debug in [False,True]:
        a,b=normalize(old,file,debug),normalize(new,file,debug)
        if a!=b:
            failures.append((file,debug))
            diff=list(difflib.unified_diff(a.split(';'),b.split(';'),fromfile='base',tofile='current'))
            (Path('/tmp')/('clockin27-ios-'+Path(file).name+'.diff')).write_text('\n'.join(diff))
    count+=1
    print(('FAIL' if any(f[0]==file for f in failures) else 'PASS')+' iOS source '+file)
# Existing catalog entries are immutable; additions cannot change the phone's text.
old=json.loads(subprocess.check_output(['git','show',f'{BASE}:Shared/Localizable.xcstrings'],cwd=root,text=True))
new=json.loads((root/'Shared/Localizable.xcstrings').read_text())
assert all(new['strings'].get(k)==v for k,v in old['strings'].items()),'existing localization changed'
added=set(new['strings'])-set(old['strings'])
assert all(set(new['strings'][k]['localizations']) >= {'en','tr'} for k in added)
print(f'{count} shared files checked in release and DEBUG; {len(added)} bilingual additions; existing strings unchanged')
if failures:
    print('Failures:',failures)
    raise SystemExit(1)
