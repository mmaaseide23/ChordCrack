-- Read-only post-deployment check; no application records are returned.
BEGIN READ ONLY;
SELECT md5(jsonb_build_object(
 'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY tablename,policyname) FROM pg_policies p WHERE schemaname='public' AND tablename <> 'profile_avatars'),
 'objects',(SELECT jsonb_agg(jsonb_build_object('name',c.relname,'acl',c.relacl,'options',c.reloptions,'rls',c.relrowsecurity,'owner',c.relowner,'definition',CASE WHEN c.relkind='v' THEN pg_get_viewdef(c.oid,true) END) ORDER BY c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','v') AND c.relname <> 'profile_avatars'),
 'columns',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',a.attname,'acl',a.attacl) ORDER BY c.relname,a.attnum) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','v') AND c.relname <> 'profile_avatars' AND a.attnum>0 AND NOT a.attisdropped)
)::text) AS existing_access_fingerprint,
 NOT EXISTS (SELECT 1 FROM auth.users WHERE id IN (
 '816cf408-2417-469f-90f7-2a034d719001','816cf408-2417-469f-90f7-2a034d719002',
 '816cf408-2417-469f-90f7-2a034d719003','816cf408-2417-469f-90f7-2a034d719004',
 '816cf408-2417-469f-90f7-2a034d719005')) AS synthetic_accounts_removed,
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.profile_avatars'::regclass) AS avatar_rls_enabled,
 (SELECT NOT prosecdef FROM pg_proc WHERE oid='public.set_profile_avatar(text,uuid)'::regprocedure) AS rpc_is_invoker,
 NOT has_table_privilege('anon','public.profile_avatars','SELECT') AS anonymous_read_denied,
 NOT has_function_privilege('anon','public.set_profile_avatar(text,uuid)','EXECUTE') AS anonymous_rpc_denied;
COMMIT;
