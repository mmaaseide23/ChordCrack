#!/usr/bin/env python3
"""Synthetic PostgreSQL only, temporary Unix socket; no Supabase or TCP listener."""
import json, os, subprocess, tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parents[1]
pg = Path(os.environ.get('POSTGRES_BIN', '/opt/homebrew/opt/postgresql@17/bin'))
logs = []
def run(args):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    logs.append(result.stdout + result.stderr)
    if result.returncode: raise RuntimeError(logs[-1])
    return result.stdout

with tempfile.TemporaryDirectory(prefix='cc-avatar-pg-', dir='/tmp') as tmp:
    work = Path(tmp)
    data = work / 'data'
    def sql(path=None, text=None):
        args = [pg/'psql', '-X', '-h', work, '-p', '59427', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-At']
        return run(args + (['-f', path] if path else ['-c', text]))
    started = False
    try:
        run([pg/'initdb', '-D', data, '-U', 'postgres', '--auth-local=trust', '--auth-host=reject', '--no-locale'])
        run([pg/'pg_ctl', '-D', data, '-l', work/'server.log', '-o', f"-h '' -k '{work}' -p 59427", '-w', 'start'])
        started = True
        sql(root/'scripts/verify-social-privacy/fixture.sql')
        sql(root/'supabase/migrations/20261102150000_social_privacy.sql')
        snapshot = """SELECT jsonb_build_object('policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY tablename,policyname)
          FROM pg_policies p WHERE schemaname='public' AND tablename<>'profile_avatars'),
          'objects',(SELECT jsonb_agg(jsonb_build_object('name',c.relname,'acl',c.relacl,'options',c.reloptions,
          'definition',CASE WHEN c.relkind='v' THEN pg_get_viewdef(c.oid,true) ELSE NULL END) ORDER BY c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'
          AND c.relkind IN ('r','v') AND c.relname<>'profile_avatars'));"""
        before = json.loads(sql(text=snapshot))
        migration = root/'supabase/migrations/20261104120000_profile_avatars.sql'
        sql(migration)
        assert before == json.loads(sql(text=snapshot)), 'Existing policies, grants or views changed'
        sql(here/'database.sql')
        sql(root/'supabase/rollback/20261104120000_profile_avatars.sql')
        assert before == json.loads(sql(text=snapshot)), 'Rollback changed existing objects'
        assert sql(text="SELECT to_regclass('public.profile_avatars') IS NULL AND to_regprocedure('public.set_profile_avatar(text,uuid)') IS NULL").strip() == 't'
        sql(migration) # Reapply after rollback proves no leftover objects.
        count = sum(log.count('NOTICE:  PASS:') for log in logs)
        print(json.dumps({'status':'passed', 'checks':count, 'existing_access_unchanged':True,
            'rollback_and_reapply':True, 'production_access':False, 'tcp_listener':False}))
    except Exception:
        print('\n'.join(logs[-4:]))
        raise
    finally:
        if started: run([pg/'pg_ctl', '-D', data, '-m', 'fast', '-w', 'stop'])
