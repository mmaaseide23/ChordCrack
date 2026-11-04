-- Read-only catalog inspection. Returns no application records or credentials.
BEGIN READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT 'objects' AS section, jsonb_agg(jsonb_build_object(
  'name', c.relname, 'kind', c.relkind, 'owner', pg_get_userbyid(c.relowner),
  'rls', c.relrowsecurity, 'force_rls', c.relforcerowsecurity,
  'options', c.reloptions, 'grants', c.relacl,
  'definition', CASE WHEN c.relkind = 'v' THEN pg_get_viewdef(c.oid, true) END
) ORDER BY c.relname)::text AS details
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN
 ('user_stats','user_privacy_settings','friends','social_profiles','leaderboard','profile_avatars')
UNION ALL
SELECT 'policies', jsonb_agg(to_jsonb(p) ORDER BY tablename, policyname)::text
FROM pg_policies p WHERE schemaname='public' AND tablename IN
 ('user_stats','user_privacy_settings','friends','profile_avatars')
UNION ALL
SELECT 'triggers', coalesce(jsonb_agg(jsonb_build_object(
 'schema', n.nspname, 'table', c.relname, 'name', t.tgname,
 'definition', pg_get_triggerdef(t.oid),
 'function', t.tgfoid::regprocedure::text,
 'function_definition', pg_get_functiondef(t.tgfoid)
) ORDER BY n.nspname,c.relname,t.tgname), '[]')::text
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND ((n.nspname='auth' AND c.relname='users') OR
 (n.nspname='public' AND c.relname IN ('user_stats','user_privacy_settings','friends')))
UNION ALL
SELECT 'avatar_rpc', coalesce(jsonb_agg(jsonb_build_object(
 'signature',p.oid::regprocedure::text,'definition',pg_get_functiondef(p.oid),'grants',p.proacl)), '[]')::text
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='set_profile_avatar';
COMMIT;
