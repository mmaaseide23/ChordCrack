-- Removes saved avatar choices. Export them first if preservation is required.
-- Does not alter statistics, privacy, friendship or leaderboard definitions.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DROP FUNCTION public.set_profile_avatar(text, uuid);
DROP TABLE public.profile_avatars; -- no CASCADE: unexpected dependencies abort
NOTIFY pgrst, 'reload schema';
COMMIT;
