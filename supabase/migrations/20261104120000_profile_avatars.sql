-- Curated avatar IDs only. Requires the social-privacy migration; no photo storage.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
BEGIN
  IF to_regclass('public.profile_avatars') IS NOT NULL OR
     EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='set_profile_avatar') THEN
    RAISE EXCEPTION 'Avatar objects already exist; inspect migration history';
  END IF;
  IF to_regclass('public.social_profiles') IS NULL OR
     NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.user_stats'::regclass) OR
     NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.leaderboard'::regclass
                 AND reloptions @> ARRAY['security_barrier=true']) OR
     EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_stats'
             AND cmd IN ('SELECT','ALL') AND qual='true') THEN
    RAISE EXCEPTION 'Apply and verify social privacy migration first';
  END IF;
END
$preflight$;

CREATE TABLE public.profile_avatars (
  user_id uuid PRIMARY KEY REFERENCES public.user_stats(id) ON DELETE CASCADE,
  avatar_id text NOT NULL CHECK (avatar_id IN
    ('initial','guitar','keys','headphones','note','wave','bolt','star','sparkle'))
);
ALTER TABLE public.profile_avatars ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_avatars FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id, avatar_id), INSERT (user_id, avatar_id), UPDATE (avatar_id)
  ON public.profile_avatars TO authenticated;

-- Invoker queries inherit the existing stats RLS and leaderboard consent filter.
-- No avatar is added to the globally searchable username-only directory.
CREATE POLICY "Read avatars for visible profiles" ON public.profile_avatars
FOR SELECT TO authenticated USING (
  user_id = (SELECT auth.uid())
  OR EXISTS (SELECT 1 FROM public.user_stats us WHERE us.id = profile_avatars.user_id)
  OR EXISTS (SELECT 1 FROM public.leaderboard lb WHERE lb.user_id = profile_avatars.user_id)
);
CREATE POLICY "Insert own avatar" ON public.profile_avatars
FOR INSERT TO authenticated WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "Update own avatar" ON public.profile_avatars
FOR UPDATE TO authenticated USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- Expected identity is a session-switch guard, never an authorization source.
-- auth.uid() remains authoritative; no service credential or definer privilege.
-- Only avatar_id is updated on conflict, so no user_id UPDATE grant is needed.
CREATE FUNCTION public.set_profile_avatar(p_avatar_id text, p_expected_user_id uuid)
RETURNS SETOF public.profile_avatars
LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path = '' AS $function$
BEGIN
  IF auth.uid() IS NULL OR p_expected_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Session changed; reload profile' USING ERRCODE='42501';
  END IF;
  RETURN QUERY INSERT INTO public.profile_avatars(user_id, avatar_id)
  VALUES (auth.uid(), p_avatar_id)
  ON CONFLICT (user_id) DO UPDATE SET avatar_id = EXCLUDED.avatar_id
  RETURNING user_id, avatar_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.set_profile_avatar(text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_profile_avatar(text, uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
