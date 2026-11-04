#!/usr/bin/env python3
"""Actual avatar/social code, in-memory transport; no network, accounts, photos or audio."""
import hashlib, json, subprocess, tempfile
from pathlib import Path
here = Path(__file__).resolve().parent
root = here.parents[1]
files = ['ChordCrack/Models/Models.swift', 'ChordCrack/Models/SocialModels.swift',
    'ChordCrack/Models/ProfileAvatar.swift', 'ChordCrack/Services/Social/AvatarAPIService.swift',
    'ChordCrack/Services/ProfileAvatarStore.swift', 'ChordCrack/Services/Social/SocialAPIService.swift']
parts = [(here.parent/'verify-social-services/TestSupport.swift').read_text()]
hashes = {}
for file in files:
    data = (root/file).read_bytes()
    parts.append(data.decode()); hashes[file] = hashlib.sha256(data).hexdigest()
parts.append((here/'Checks.swift').read_text())
with tempfile.TemporaryDirectory(prefix='cc-avatar-swift-') as tmp:
    folder = Path(tmp)
    (folder/'Checks.swift').write_text('\n\n'.join(parts))
    subprocess.run(['xcrun','swiftc','-swift-version','5','-parse-as-library','-module-cache-path',str(folder/'cache'),str(folder/'Checks.swift'),'-o',str(folder/'checks')],check=True)
    result = subprocess.run([str(folder/'checks')],capture_output=True,text=True,timeout=30)
    print(result.stdout,end=''); print(result.stderr,end=''); result.check_returncode()
    print('Source SHA-256:',json.dumps(hashes,sort_keys=True))
