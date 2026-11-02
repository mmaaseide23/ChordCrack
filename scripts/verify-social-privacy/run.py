#!/usr/bin/env python3
"""Run migrations against an isolated synthetic PostgreSQL 17 cluster.
No TCP listener, production connection, account credentials or installed services.
"""
import json, os, subprocess, tempfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
PG=Path(os.environ.get('POSTGRES_BIN','/opt/homebrew/opt/postgresql@17/bin'))
work=Path(tempfile.mkdtemp(prefix='ccqa-pg-',dir=HERE))
socket=Path(tempfile.mkdtemp(prefix='ccqa-pgs-',dir='/tmp'))
data=work/'data'; output=[]
def cmd(args,**kwargs):
    result=subprocess.run([str(x) for x in args],text=True,capture_output=True,**kwargs)
    output.append(result.stdout+result.stderr)
    if result.returncode: raise RuntimeError(result.stdout+result.stderr)
    return result.stdout
def sql(file=None,text=None):
    args=[PG/'psql','-X','-h',socket,'-p','59426','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-At']
    return cmd(args+(['-f',file] if file else ['-c',text]))
started=False
try:
    cmd([PG/'initdb','-D',data,'-U','postgres','--auth-local=trust','--auth-host=reject','--no-locale'])
    cmd([PG/'pg_ctl','-D',data,'-l',work/'server.log','-o',f"-h '' -k '{socket}' -p 59426",'-w','start']); started=True
    sql(HERE/'fixture.sql')
    snapshot="SELECT jsonb_build_object('policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY tablename,policyname) FROM pg_policies p WHERE schemaname='public'),'views',(SELECT jsonb_object_agg(c.relname,jsonb_build_object('def',pg_get_viewdef(c.oid,true),'options',c.reloptions)) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='v'),'friend_acl',(SELECT relacl FROM pg_class WHERE oid='friends'::regclass),'friend_columns',(SELECT jsonb_agg(jsonb_build_object('name',attname,'acl',attacl) ORDER BY attnum) FROM pg_attribute WHERE attrelid='friends'::regclass AND attnum>0));"
    before=json.loads(sql(text=snapshot))
    sql(HERE.parents[1]/'supabase/migrations/20261102150000_social_privacy.sql')
    sql(HERE/'regression.sql')
    sql(HERE.parents[1]/'supabase/rollback/20261102150000_social_privacy.sql')
    after=json.loads(sql(text=snapshot))
    # Postgres may represent removed column ACL as an empty array instead of NULL.
    for value in [before,after]:
        for column in value['friend_columns']: column['acl']=column['acl'] or []
        value['friend_acl']=sorted(value['friend_acl'])
    assert before==after, 'Rollback did not restore catalog definitions/ACLs'
    count=sum(x.count('NOTICE:  PASS:') for x in output)
    result={'status':'passed','regressions_passed':count,'rollback_catalog_equivalence':True,'production_access':False,'tcp_listener':False,'cluster':str(work)}
    print(json.dumps(result))
except Exception as error:
    result={'status':'failed','error':str(error),'production_access':False,'cluster':str(work)}
    print(json.dumps(result))
    raise
finally:
    if started: cmd([PG/'pg_ctl','-D',data,'-m','fast','-w','stop'])
    if not any(socket.iterdir()): socket.rmdir()
    (HERE/'local-test.log').write_text('\n'.join(output))
    (HERE/'local-test-result.json').write_text(json.dumps(result,indent=2)+'\n')
