-- Only for the isolated synthetic cluster created by database.py.
CREATE FUNCTION pg_temp.assert(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF; RAISE NOTICE 'PASS: %',label; END $$;
CREATE FUNCTION pg_temp.denied(command text, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN EXECUTE command; EXCEPTION WHEN insufficient_privilege OR invalid_parameter_value OR check_violation THEN
    RAISE NOTICE 'PASS: %',label; RETURN; END;
  RAISE EXCEPTION 'FAIL: %',label;
END $$;
SELECT floor(extract(epoch FROM now())/86400)::integer AS today \gset
UPDATE public.user_privacy_settings SET data_processing_consent=true;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
SELECT pg_temp.denied('INSERT INTO public.daily_riff_results VALUES (auth.uid(),0,2,ARRAY[true,true,true,true,true],true,now())','direct insert denied');
SELECT pg_temp.denied('UPDATE public.daily_riff_results SET included=true','direct update denied');
SELECT pg_temp.denied('DELETE FROM public.daily_riff_results','direct delete denied');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],false,auth.uid())',:today),'explicit consent required');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,%L)',:today,'22222222-2222-2222-2222-222222222222'),'owner mismatch denied');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true],true,auth.uid())',:today),'incomplete result denied');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,NULL],true,auth.uid())',:today),'null result denied');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,1,ARRAY[true,true,true,true,true],true,auth.uid())',:today),'legacy version rejected');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,auth.uid())',:today-1),'backdated contribution rejected');
SELECT public.submit_daily_riff(:today,2,ARRAY[true,true,true,true,true],true,auth.uid());
SELECT public.submit_daily_riff(:today,2,ARRAY[true,true,true,true,true],true,auth.uid());
SELECT pg_temp.assert((SELECT count(*)=1 FROM public.daily_riff_results),'owner reads own, duplicate idempotent');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[false,false,false,false,false],true,auth.uid())',:today),'first result immutable');
SELECT pg_temp.assert(public.daily_riff_summary(:today,2) = jsonb_build_object('status','waiting','day',:today,'version',2),'small cohort exposes no totals');
SELECT set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
SELECT pg_temp.assert((SELECT count(*)=0 FROM public.daily_riff_results),'friend cannot read raw contribution');
SELECT set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
SELECT pg_temp.assert((SELECT count(*)=0 FROM public.daily_riff_results),'stranger cannot read raw contribution');
SELECT set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444444',false);
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,auth.uid())',:today),'missing privacy consent denied');
RESET ROLE;
UPDATE public.user_privacy_settings SET data_processing_consent=NULL WHERE user_id='55555555-5555-5555-5555-555555555555';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','55555555-5555-5555-5555-555555555555',false);
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,auth.uid())',:today),'null privacy consent denied');
RESET ROLE;
INSERT INTO public.user_stats(id,username) SELECT ('90000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'RiffFixture'||n FROM generate_series(1,24) n;
INSERT INTO public.user_privacy_settings(user_id,data_processing_consent,share_stats,show_on_leaderboard)
  SELECT id,true,false,false FROM public.user_stats WHERE username LIKE 'RiffFixture%';
INSERT INTO public.daily_riff_results(user_id,day,version,correct,included)
  SELECT id,:today,2,CASE WHEN substring(username FROM 12)::int<=4 THEN ARRAY[false,false,false,false,false]
    WHEN substring(username FROM 12)::int<=14 THEN ARRAY[true,true,true,false,false]
    ELSE ARRAY[true,true,true,true,true] END,true
  FROM public.user_stats WHERE username LIKE 'RiffFixture%';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->>'participantsLower'='20','population bucket, independent leaderboard consent');
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->'scoreBands'='[null,10,10]'::jsonb,'tiny score group hidden, larger groups bucketed');
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->'roundRates'='[80,80,80,40,40]'::jsonb,'per-round rates are coarse, synthetic math correct');
SELECT pg_temp.assert((SELECT count(*)=1 FROM public.daily_riff_results),'population never expands raw RLS');
SELECT public.withdraw_daily_riff(:today,2,auth.uid());
SELECT pg_temp.assert((SELECT included=false FROM public.daily_riff_results),'withdrawal saved');
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->'roundRates'='[80,80,80,40,40]'::jsonb,'withdrawal excludes contribution');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[false,false,false,false,false],true,auth.uid())',:today),'withdrawal cannot reset first answer');
SELECT public.submit_daily_riff(:today,2,ARRAY[true,true,true,true,true],true,auth.uid());
RESET ROLE;
UPDATE public.daily_riff_results SET included=false WHERE user_id IN (
  SELECT id FROM public.user_stats WHERE username IN ('RiffFixture1','RiffFixture2','RiffFixture3','RiffFixture4','RiffFixture5'));
SET ROLE authenticated;
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->>'status'='available','twenty-player boundary publishes');
SELECT pg_temp.denied(format('SELECT public.withdraw_daily_riff(%s,2,%L)',:today,'22222222-2222-2222-2222-222222222222'),'cross-owner withdrawal denied');
SELECT public.withdraw_daily_riff(:today,2,auth.uid());
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->>'status'='waiting','withdrawal immediately removes participant at boundary');
SELECT public.submit_daily_riff(:today,2,ARRAY[true,true,true,true,true],true,auth.uid());
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->>'status'='available','same first result may be included again');
RESET ROLE;
UPDATE public.daily_riff_results SET included=true;
UPDATE public.user_privacy_settings SET data_processing_consent=false WHERE user_id='11111111-1111-1111-1111-111111111111';
SET ROLE authenticated;
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,auth.uid())',:today),'revoked processing consent blocks submission');
SELECT public.withdraw_daily_riff(:today,2,auth.uid());
SELECT pg_temp.assert((SELECT included=false FROM public.daily_riff_results),'withdrawal allowed after privacy revoke');
SELECT pg_temp.denied('SELECT public.purge_expired_daily_riffs()','retention admin only');
RESET ROLE;
UPDATE public.user_privacy_settings SET data_processing_consent=false WHERE user_id IN (
 SELECT id FROM public.user_stats WHERE username IN ('RiffFixture1','RiffFixture2','RiffFixture3','RiffFixture4','RiffFixture5'));
SET ROLE authenticated;
SELECT pg_temp.assert(public.daily_riff_summary(:today,2)->>'status'='waiting','processing revocation removes rows from aggregates');
SELECT pg_temp.denied(format('SELECT public.daily_riff_summary(%s,2)',:today+1),'future summary rejected');
SELECT pg_temp.denied(format('SELECT public.daily_riff_summary(%s,2)',:today-30),'expired summary rejected');
SELECT set_config('request.jwt.claim.sub','',false);
SELECT pg_temp.denied(format('SELECT public.daily_riff_summary(%s,2)',:today),'missing JWT denied');
RESET ROLE;
SET ROLE anon;
SELECT pg_temp.denied('SELECT * FROM public.daily_riff_results','anonymous raw read denied');
SELECT pg_temp.denied(format('SELECT public.daily_riff_summary(%s,2)',:today),'anonymous summary denied');
SELECT pg_temp.denied(format('SELECT public.submit_daily_riff(%s,2,ARRAY[true,true,true,true,true],true,NULL)',:today),'anonymous write denied');
RESET ROLE;
UPDATE public.daily_riff_results SET day=:today-30 WHERE user_id='11111111-1111-1111-1111-111111111111';
SELECT public.purge_expired_daily_riffs();
SELECT pg_temp.assert(NOT EXISTS(SELECT 1 FROM public.daily_riff_results WHERE day=:today-30),'expired records purged');
SELECT pg_temp.assert((SELECT count(*)=24 FROM public.daily_riff_results),'retention keeps current records');
DELETE FROM public.user_privacy_settings WHERE user_id='90000000-0000-0000-0000-000000000001';
DELETE FROM public.user_stats WHERE id='90000000-0000-0000-0000-000000000001';
SELECT pg_temp.assert(NOT EXISTS(SELECT 1 FROM public.daily_riff_results WHERE user_id='90000000-0000-0000-0000-000000000001'),'account profile deletion cascades contribution');
