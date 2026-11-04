#!/usr/bin/env python3
"""Compile production catalog/player/session with a silent fake backend. No media or AVFoundation."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parents[1]
files = [
    'ChordCrack/Models/SongClipCatalog.swift',
    'ChordCrack/Services/SongClipPlayer.swift',
    'ChordCrack/Services/SongGuessingSession.swift',
]
parts, hashes = [], {}
for relative in files:
    data = (root / relative).read_bytes()
    hashes[relative] = hashlib.sha256(data).hexdigest()
    parts.append(data.decode())
parts.append((here / 'Checks.swift').read_text())
with tempfile.TemporaryDirectory(prefix='chordcrack-silent-song-') as tmp:
    folder = Path(tmp)
    source = folder / 'Checks.swift'
    source.write_text('\n\n'.join(parts))
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-D', 'DEBUG',
                    '-parse-as-library', '-module-cache-path', str(folder / 'cache'),
                    str(source), '-o', str(folder / 'checks')], check=True)
    result = subprocess.run([str(folder / 'checks')], capture_output=True, text=True, timeout=30)
    print(result.stdout, end='')
    if result.stderr:
        print(result.stderr, end='')
    result.check_returncode()
    print('Source SHA-256:', json.dumps(hashes, sort_keys=True))
