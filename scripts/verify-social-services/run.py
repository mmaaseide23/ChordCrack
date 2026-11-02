#!/usr/bin/env python3
"""Silent regressions for actual social services with in-memory transport/storage.

Run from any directory. Optional --output-dir retains sanitized results and source
hashes; otherwise generated files live in a temporary directory. This does not
launch the app, invoke Supabase Auth, open sockets, or play audio.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path)
args = parser.parse_args()
script_dir = Path(__file__).resolve().parent
root = script_dir.parents[1]
files = [
    'ChordCrack/Models/Models.swift',
    'ChordCrack/Models/SocialModels.swift',
    'ChordCrack/Services/Auth/PrivacySettings.swift',
    'ChordCrack/Services/Social/SocialAPIService.swift',
    'ChordCrack/Services/Social/SocialManager.swift',
    'ChordCrack/Services/Auth/AccountManagementService.swift',
]

def run(output: Path) -> int:
    output.mkdir(parents=True, exist_ok=True)
    parts = [(script_dir / 'TestSupport.swift').read_text()]
    manifest = []
    for relative in files:
        source = (root / relative).read_bytes()
        manifest.append({'file': relative, 'sha256': hashlib.sha256(source).hexdigest()})
        parts.append(source.decode())
    parts.append((script_dir / 'AuditTests.swift').read_text())
    combined = output / 'CompiledAudit.swift'
    combined.write_text('\n\n'.join(parts))
    (output / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    binary = output / 'social-audit'
    subprocess.run([
        'xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
        '-module-cache-path', str(output / 'module-cache'), str(combined), '-o', str(binary)
    ], check=True)
    completed = subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=30)
    result = json.loads(completed.stdout)
    (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"{result['passed']} passed, {result['failed']} failed; no network, real records or audio.")
    for test in result['tests']:
        if test['status'] == 'failed':
            print(f"FAIL {test['test']}: {test.get('detail', '')}")
    if args.output_dir:
        print(f'Results: {output / "results.json"}')
    return 1 if result['failed'] else 0

if args.output_dir:
    sys.exit(run(args.output_dir.resolve()))
with tempfile.TemporaryDirectory(prefix='chordcrack-social-regressions-') as temporary:
    sys.exit(run(Path(temporary)))
