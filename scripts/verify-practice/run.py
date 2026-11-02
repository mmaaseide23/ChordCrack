#!/usr/bin/env python3
"""Silent tests of actual audio/session/chord logic using an in-memory player.

AVFoundation is removed only in the temporary compiled fixture and replaced by
a deterministic player. No app, account, simulator, device audio or Firebase SDK
is used. These checks do not establish real audio quality or device interruptions.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parents[1]
files = [
    'ChordCrack/Models/ChordType.swift',
    'ChordCrack/Models/DifficultyLevel.swift',
    'ChordCrack/Theme/ColorTheme.swift',
    'ChordCrack/App/DesignDemo.swift',
    'ChordCrack/Services/AudioManager.swift',
    'ChordCrack/Services/FiveRoundPracticeSession.swift',
]
parts = [(here / 'Support.swift').read_text()]
manifest = {}
for relative in files:
    data = (root / relative).read_bytes()
    manifest[relative] = hashlib.sha256(data).hexdigest()
    parts.append(data.decode().replace('import AVFoundation\n', ''))
# This production extension belongs to the shared game view; compile it verbatim.
shared = (root / 'ChordCrack/Views/Game/ConsistentGameComponents.swift').read_text()
start = shared.index('extension AudioManager {')
depth, end = 1, start + len('extension AudioManager {')
while depth:
    depth += (shared[end] == '{') - (shared[end] == '}')
    end += 1
parts.append(shared[start:end])
parts.append((here / 'Checks.swift').read_text())
with tempfile.TemporaryDirectory(prefix='chordcrack-silent-practice-') as tmp:
    folder = Path(tmp)
    fixture = folder / 'Checks.swift'
    fixture.write_text('\n\n'.join(parts))
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-D', 'DEBUG',
                    '-parse-as-library', '-module-cache-path', str(folder / 'cache'),
                    str(fixture), '-o', str(folder / 'checks')], check=True)
    result = subprocess.run([str(folder / 'checks'), '--design-demo'], check=True,
                            capture_output=True, text=True, timeout=30)
    print(result.stdout, end='')
    print('Source SHA-256:', json.dumps(manifest, sort_keys=True))
