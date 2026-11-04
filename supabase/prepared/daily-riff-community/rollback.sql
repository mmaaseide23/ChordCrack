-- Removes only the proposed daily contribution feature. Export consented data first if needed.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DROP FUNCTION public.submit_daily_riff(integer,integer,boolean[],boolean,uuid);
DROP FUNCTION public.withdraw_daily_riff(integer,integer,uuid);
DROP FUNCTION public.daily_riff_summary(integer,integer);
DROP FUNCTION public.purge_expired_daily_riffs();
DROP TABLE public.daily_riff_results;
NOTIFY pgrst, 'reload schema';
COMMIT;
