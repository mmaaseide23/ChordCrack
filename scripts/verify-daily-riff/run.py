#!/usr/bin/env python3
"""Exercise production Daily Riff/session/audio logic with a silent player substitute.

Only AVFoundation is replaced; no sound, account, telemetry or network is used.
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
    'ChordCrack/Theme/ColorTheme.swift',
    'ChordCrack/App/DesignDemo.swift',
    'ChordCrack/Services/AudioManager.swift',
    'ChordCrack/Models/DailyRiffPuzzle.swift',
    'ChordCrack/Models/DailyRiffCommunity.swift',
    'ChordCrack/Services/DailyRiffSession.swift',
]
parts = [(here.parent / 'verify-practice/Support.swift').read_text().replace('0..<200', '0..<1200')]
manifest = {}
for relative in files:
    data = (root / relative).read_bytes()
    manifest[relative] = hashlib.sha256(data).hexdigest()
    parts.append(data.decode().replace('import AVFoundation\n', ''))
parts.append((here / 'Checks.swift').read_text())
with tempfile.TemporaryDirectory(prefix='chordcrack-silent-riff-') as tmp:
    folder = Path(tmp)
    fixture = folder / 'Checks.swift'
    fixture.write_text('\n\n'.join(parts))
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-D', 'DEBUG',
                    '-parse-as-library', '-module-cache-path', str(folder / 'cache'),
                    str(fixture), '-o', str(folder / 'checks')], check=True)
    result = subprocess.run([str(folder / 'checks'), '--design-demo'], check=True,
                            capture_output=True, text=True, timeout=120)
    print(result.stdout, end='')
    print('Source SHA-256:', json.dumps(manifest, sort_keys=True))
