#!/usr/bin/env python3
"""Dry-run the hosted SQL probe in temporary local PostgreSQL; never connects remotely."""
import hashlib, os, subprocess, tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parents[1]
pg = Path(os.environ.get('POSTGRES_BIN', '/opt/homebrew/opt/postgresql@17/bin'))
def run(args):
    result = subprocess.run([str(x) for x in args], text=True, capture_output=True)
    if result.returncode: raise RuntimeError(result.stdout + result.stderr)
    return result.stdout

with tempfile.TemporaryDirectory(prefix='cc-avatar-probe-', dir='/tmp') as tmp:
    work = Path(tmp); data = work/'data'; started = False
    def sql(file=None, text=None):
        return run([pg/'psql','-X','-h',work,'-p','59428','-U','postgres','-d','postgres',
                    '-v','ON_ERROR_STOP=1','-At'] + (['-f',file] if file else ['-c',text]))
    try:
        run([pg/'initdb','-D',data,'-U','postgres','--auth-local=trust','--auth-host=reject','--no-locale'])
        run([pg/'pg_ctl','-D',data,'-l',work/'server.log','-o',f"-h '' -k '{work}' -p 59428",'-w','start'])
        started = True
        sql(root/'scripts/verify-social-privacy/fixture.sql')
        sql(text="""CREATE TABLE auth.users(id uuid PRIMARY KEY);
            INSERT INTO auth.users SELECT id FROM public.user_stats;
            ALTER TABLE public.user_stats ADD FOREIGN KEY(id) REFERENCES auth.users(id) ON DELETE CASCADE;
            ALTER TABLE public.friends ALTER COLUMN id SET DEFAULT gen_random_uuid();""")
        sql(root/'supabase/migrations/20261102150000_social_privacy.sql')
        sql(root/'supabase/migrations/20261104120000_profile_avatars.sql')
        result = sql(here/'live-permissions.sql')
        checks = [line for line in result.splitlines() if line.endswith('|t')]
        assert len(checks) == 16, result
        assert sql(text="SELECT count(*) FROM auth.users WHERE id::text LIKE '816cf408-2417-469f-90f7-2a034d71900%'").strip() == '0'
        print('\n'.join(checks))
        print('PASS: 16 hosted-probe dry-run checks; fixtures rolled back.')
        print('Probe SHA-256:',hashlib.sha256((here/'live-permissions.sql').read_bytes()).hexdigest())
    finally:
        if started: run([pg/'pg_ctl','-D',data,'-m','fast','-w','stop'])
