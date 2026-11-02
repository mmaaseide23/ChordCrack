-- Emergency rollback to the catalog snapshot taken before this migration.
-- Restores the prior privacy exposure. Never run as routine cleanup.
-- Restore the app's username lookup to user_stats before dropping its new view.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
ALTER POLICY "Users can insert friend requests" ON public.friends
WITH CHECK (user_id = auth.uid());
-- ALTER POLICY cannot remove an explicit WITH CHECK expression, so recreate
-- this one policy exactly as captured. No application records are deleted.
DROP POLICY "Users can update their friend relationships" ON public.friends;
CREATE POLICY "Users can update their friend relationships" ON public.friends
AS PERMISSIVE FOR UPDATE TO authenticated
USING ((user_id = auth.uid()) OR (friend_id = auth.uid()));
REVOKE UPDATE (status, updated_at) ON public.friends FROM authenticated;
GRANT UPDATE ON public.friends TO authenticated;
ALTER POLICY "Public can view user stats for leaderboard and friends"
ON public.user_stats TO authenticated USING (true);
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT row_number() OVER (ORDER BY best_score DESC, total_games DESC) AS rank,
  id AS user_id, username, best_score, total_games, best_streak,
  average_score, total_correct, total_questions
FROM public.user_stats us WHERE total_games > 0
ORDER BY best_score DESC, total_games DESC;
ALTER VIEW public.leaderboard RESET (security_barrier);
DROP VIEW public.social_profiles; -- no CASCADE; abort if unexpected dependents
NOTIFY pgrst, 'reload schema';
COMMIT;
