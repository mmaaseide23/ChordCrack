#!/usr/bin/env python3
"""Compile actual Analytics manager + app initializer with memory-only SDK spies.

No Firebase SDK, network, app container, simulator or audio is used. Only the
Firebase import is removed; the initializer body is extracted without edits.
"""
from pathlib import Path
import hashlib, json, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
manager=root/'ChordCrack/Services/Analytics/FirebaseAnalyticsManager.swift'
app=root/'ChordCrack/App/ChordCrackApp.swift'
source=manager.read_text().replace('import FirebaseAnalytics\n','')
app_source=app.read_text()
start=app_source.index('    init() {')+len('    init() {')
depth=1
end=start
while depth:
    depth += (app_source[end]=='{')-(app_source[end]=='}')
    end+=1
initializer=app_source[start:end-1]
parts=[(here/'Support.swift').read_text(),source,'@MainActor func bootstrap() {\n'+initializer+'\n}',
       'let supportsDemo = '+str('DesignDemo.isEnabled' in source).lower(),(here/'Checks.swift').read_text()]
with tempfile.TemporaryDirectory(prefix='chordcrack-analytics-') as tmp:
    path=Path(tmp)
    combined=path/'Checks.swift'
    combined.write_text('\n\n'.join(parts))
    subprocess.run(['xcrun','swiftc','-swift-version','5','-parse-as-library','-module-cache-path',str(path/'cache'),str(combined),'-o',str(path/'checks')],check=True)
    result=subprocess.run([str(path/'checks')],check=True,capture_output=True,text=True,timeout=20)
    print(result.stdout,end='')
    print('Source SHA-256:',json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (manager,app)}))
