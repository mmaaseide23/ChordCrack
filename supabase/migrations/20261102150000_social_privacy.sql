-- ChordCrack: enforce separate friend-stat and leaderboard consent.
-- Run in one transaction. Does not update/delete any application rows.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $preflight$
BEGIN
  IF current_setting('server_version_num')::int < 150000 THEN
    RAISE EXCEPTION 'PostgreSQL 15+ required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'user_stats'
      AND policyname = 'Public can view user stats for leaderboard and friends'
      AND cmd = 'SELECT' AND permissive = 'PERMISSIVE'
      AND roles = ARRAY['authenticated']::name[] AND qual = 'true'
  ) THEN
    RAISE EXCEPTION 'Expected original stats SELECT policy not found; inspect drift';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_stats'
      AND policyname = 'Users can view own stats' AND qual = '(auth.uid() = id)'
  ) OR (SELECT count(*) FROM pg_policies WHERE schemaname='public'
       AND tablename='user_stats' AND cmd IN ('SELECT','ALL')) <> 2 THEN
    RAISE EXCEPTION 'Unexpected stats read policies; owner access or privacy could differ';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.user_stats'::regclass) THEN
    RAISE EXCEPTION 'user_stats RLS must already be enabled';
  END IF;
  IF to_regclass('public.social_profiles') IS NOT NULL THEN
    RAISE EXCEPTION 'social_profiles already exists; do not overwrite';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE oid='public.leaderboard'::regclass
             AND (relkind <> 'v' OR reloptions IS NOT NULL OR pg_get_userbyid(relowner) <> 'postgres')) THEN
    RAISE EXCEPTION 'Unexpected original leaderboard kind/options/owner';
  END IF;
  IF regexp_replace(pg_get_viewdef('public.leaderboard'::regclass,true),'\s','','g') <>
     regexp_replace($original$ SELECT row_number() OVER (ORDER BY best_score DESC, total_games DESC) AS rank,
       id AS user_id, username, best_score, total_games, best_streak, average_score,
       total_correct, total_questions FROM user_stats us WHERE total_games > 0
       ORDER BY best_score DESC, total_games DESC; $original$,'\s','','g') THEN
    RAISE EXCEPTION 'Leaderboard definition changed; inspect before replacing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friends'
      AND policyname='Users can insert friend requests' AND cmd='INSERT'
      AND with_check='(user_id = auth.uid())') OR NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='friends'
      AND policyname='Users can update their friend relationships' AND cmd='UPDATE'
      AND qual='((user_id = auth.uid()) OR (friend_id = auth.uid()))' AND with_check IS NULL) THEN
    RAISE EXCEPTION 'Unexpected friendship policies; inspect before narrowing';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='public.friends'::regclass
             AND attnum>0 AND attacl IS NOT NULL) THEN
    RAISE EXCEPTION 'Existing friendship column grants need separate review';
  END IF;
END
$preflight$;

-- An accepted friendship must represent recipient consent; otherwise an
-- ordinary client could forge one and bypass the shared-friend predicate.
ALTER POLICY "Users can insert friend requests" ON public.friends
WITH CHECK (user_id = (SELECT auth.uid()) AND friend_id <> user_id AND status = 'pending');
ALTER POLICY "Users can update their friend relationships" ON public.friends
USING (friend_id = (SELECT auth.uid()) AND status = 'pending')
WITH CHECK (friend_id = (SELECT auth.uid()) AND status IN ('accepted','declined'));
-- Prevent a recipient from rewriting sender/recipient/id while accepting.
REVOKE UPDATE ON public.friends FROM authenticated;
GRANT UPDATE (status, updated_at) ON public.friends TO authenticated;
DO $permissions$
BEGIN
  IF has_table_privilege('authenticated','public.friends','UPDATE') THEN
    RAISE EXCEPTION 'Unexpected inherited table-wide UPDATE grant; abort';
  END IF;
END
$permissions$;

-- Other users need both an accepted friendship and explicit statistics consent.
-- The separate existing owner policy remains unchanged, including RETURNING.
ALTER POLICY "Public can view user stats for leaderboard and friends"
ON public.user_stats TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.user_privacy_settings p
          WHERE p.user_id = user_stats.id AND p.share_stats IS TRUE)
  AND EXISTS (
    SELECT 1 FROM public.friends f WHERE f.status = 'accepted'
      AND ((f.user_id = (SELECT auth.uid()) AND f.friend_id = user_stats.id)
        OR (f.friend_id = (SELECT auth.uid()) AND f.user_id = user_stats.id))
  )
);

-- A deliberately narrow owner-rights view keeps username lookup working even
-- when a target's statistics are private. No statistics or private preferences.
CREATE VIEW public.social_profiles WITH (security_barrier = true) AS
SELECT id, username FROM public.user_stats
WHERE (SELECT auth.uid()) IS NOT NULL;
REVOKE ALL ON public.social_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.social_profiles TO authenticated;

-- Keep existing column names/types/order so existing leaderboard decoders work.
-- Owner-rights are retained intentionally: leaderboard consent is independent
-- of friend-stat consent, and this view is a narrower projection than the table.
-- The barrier and explicit predicates apply before caller-supplied conditions.
CREATE OR REPLACE VIEW public.leaderboard WITH (security_barrier = true) AS
WITH visible AS (
  SELECT us.*,
    (us.id = (SELECT auth.uid()) OR (
      p.share_stats IS TRUE AND EXISTS (
        SELECT 1 FROM public.friends f WHERE f.status = 'accepted'
          AND ((f.user_id = (SELECT auth.uid()) AND f.friend_id = us.id)
            OR (f.friend_id = (SELECT auth.uid()) AND f.user_id = us.id))
      )
    )) AS may_read_details
  FROM public.user_stats us
  JOIN public.user_privacy_settings p ON p.user_id = us.id
  WHERE us.total_games > 0
    AND p.show_on_leaderboard IS TRUE
    AND (SELECT auth.uid()) IS NOT NULL
)
SELECT row_number() OVER (ORDER BY best_score DESC, total_games DESC) AS rank,
  id AS user_id, username, best_score, total_games,
  CASE WHEN may_read_details THEN best_streak ELSE NULL::integer END AS best_streak,
  (CASE WHEN may_read_details THEN average_score ELSE NULL END)::numeric(5,2) AS average_score,
  CASE WHEN may_read_details THEN total_correct ELSE NULL::integer END AS total_correct,
  CASE WHEN may_read_details THEN total_questions ELSE NULL::integer END AS total_questions
FROM visible
ORDER BY best_score DESC, total_games DESC;

NOTIFY pgrst, 'reload schema';
COMMIT;
