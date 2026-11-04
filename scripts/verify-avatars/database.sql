-- Only the isolated synthetic fixture database.
CREATE FUNCTION pg_temp.check(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
RAISE NOTICE 'PASS: %',label; END $$;
INSERT INTO profile_avatars SELECT id,'guitar' FROM user_stats;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
SELECT pg_temp.check((SELECT count(*)=2 FROM profile_avatars),'only self and opted-in leaderboard avatar visible');
SELECT pg_temp.check((SELECT count(*)=0 FROM profile_avatars WHERE user_id IN
 ('22222222-2222-2222-2222-222222222222','44444444-4444-4444-4444-444444444444','55555555-5555-5555-5555-555555555555')),'private friend, missing and null consent hidden');
SELECT pg_temp.check((SELECT avatar_id='keys' AND user_id=auth.uid() FROM set_profile_avatar('keys',auth.uid())),'owner RPC updates and returns own choice');
SELECT pg_temp.check((SELECT avatar_id='initial' FROM set_profile_avatar('initial',auth.uid())),'owner can restore initials');
DO $$ BEGIN
 BEGIN PERFORM set_profile_avatar('star','22222222-2222-2222-2222-222222222222'); RAISE EXCEPTION 'FAIL: switched account write allowed';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: expected-account mismatch denied'; END;
 BEGIN PERFORM set_profile_avatar('https://example.invalid/photo.jpg',auth.uid()); RAISE EXCEPTION 'FAIL: arbitrary URL accepted';
 EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS: arbitrary ID or URL rejected'; END;
 BEGIN UPDATE profile_avatars SET user_id='22222222-2222-2222-2222-222222222222' WHERE user_id=auth.uid();
 RAISE EXCEPTION 'FAIL: identity rewrite allowed'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: identity rewrite denied'; END;
 BEGIN INSERT INTO profile_avatars(user_id,avatar_id) VALUES ('99999999-9999-9999-9999-999999999999','star');
 RAISE EXCEPTION 'FAIL: cross-account insert allowed'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: cross-account insert denied'; END;
 BEGIN DELETE FROM profile_avatars; RAISE EXCEPTION 'FAIL: direct delete allowed';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: direct delete denied'; END;
END $$;
WITH changed AS (UPDATE profile_avatars SET avatar_id='bolt' WHERE user_id='33333333-3333-3333-3333-333333333333' RETURNING *)
SELECT pg_temp.check((SELECT count(*)=0 FROM changed),'visible stranger avatar cannot be changed');
SELECT pg_temp.check((SELECT count(*)=1 FROM user_stats),'avatar feature does not reveal private stats');
SELECT pg_temp.check((SELECT count(*)=2 FROM information_schema.columns WHERE table_schema='public' AND table_name='social_profiles'),'username directory remains exactly two columns');
RESET ROLE;
UPDATE user_privacy_settings SET share_stats=true WHERE user_id='22222222-2222-2222-2222-222222222222';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM profile_avatars WHERE user_id='22222222-2222-2222-2222-222222222222'),'accepted friend and stats consent reveal avatar');
RESET ROLE;
UPDATE friends SET status='pending';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM profile_avatars WHERE user_id='22222222-2222-2222-2222-222222222222'),'pending relationship does not reveal avatar');
RESET ROLE;
UPDATE friends SET status='accepted';
UPDATE user_privacy_settings SET share_stats=false,show_on_leaderboard=true WHERE user_id='22222222-2222-2222-2222-222222222222';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM profile_avatars WHERE user_id='22222222-2222-2222-2222-222222222222'),'leaderboard consent independently reveals avatar');
RESET ROLE;
UPDATE user_privacy_settings SET show_on_leaderboard=false WHERE user_id='22222222-2222-2222-2222-222222222222';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=0 FROM profile_avatars WHERE user_id='22222222-2222-2222-2222-222222222222'),'privacy revocation hides avatar immediately at server');
RESET ROLE;
UPDATE user_stats SET total_games=0 WHERE id='33333333-3333-3333-3333-333333333333';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM profile_avatars),'no-games leaderboard entry is not a visibility grant');
SELECT set_config('request.jwt.claim.sub','',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM profile_avatars),'authenticated role without identity reads nothing');
RESET ROLE;
SET ROLE anon;
DO $$ BEGIN
 BEGIN PERFORM * FROM profile_avatars; RAISE EXCEPTION 'FAIL: anonymous read allowed';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: anonymous reads denied'; END;
 BEGIN PERFORM set_profile_avatar('star',auth.uid()); RAISE EXCEPTION 'FAIL: anonymous RPC allowed';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: anonymous RPC denied'; END;
END $$;
RESET ROLE;
DELETE FROM profile_avatars WHERE user_id='44444444-4444-4444-4444-444444444444';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444444',false);
SELECT pg_temp.check((SELECT avatar_id='headphones' FROM set_profile_avatar('headphones',auth.uid())),'first selection inserts owner row');
RESET ROLE;
DELETE FROM user_stats WHERE id='44444444-4444-4444-4444-444444444444';
SELECT pg_temp.check((SELECT count(*)=0 FROM profile_avatars WHERE user_id='44444444-4444-4444-4444-444444444444'),'deleting profile cascades avatar removal');
SELECT pg_temp.check((SELECT NOT prosecdef FROM pg_proc WHERE oid='set_profile_avatar(text,uuid)'::regprocedure),'RPC has no definer privilege');
