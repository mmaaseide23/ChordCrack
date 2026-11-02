-- Synthetic local fixture only. psql must use ON_ERROR_STOP=1.
CREATE FUNCTION pg_temp.check(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
RAISE NOTICE 'PASS: %',label; END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
SELECT pg_temp.check((SELECT count(*)=1 FROM user_stats),'owner visible; private friend and unrelated users hidden');
SELECT pg_temp.check((SELECT count(*)=1 FROM leaderboard),'only opted-in leaderboard member visible');
SELECT pg_temp.check((SELECT best_streak IS NULL AND average_score IS NULL AND total_correct IS NULL AND total_questions IS NULL FROM leaderboard WHERE username='FixtureStranger'),'leaderboard does not expose nonfriend detailed stats');
SELECT pg_temp.check((SELECT count(*)=5 FROM social_profiles),'private usernames remain searchable');
SELECT pg_temp.check((SELECT count(*)=1 FROM social_profiles WHERE username='FixtureFriend'),'friend lookup works without stats permission');
SELECT pg_temp.check((SELECT count(*)=1 FROM friends_with_usernames WHERE requester_username='FixtureOwner' AND recipient_username='FixtureFriend'),'private friend names remain intact');
UPDATE user_stats SET best_score=11 WHERE id='11111111-1111-1111-1111-111111111111';
SELECT pg_temp.check((SELECT best_score=11 FROM user_stats WHERE id=auth.uid()),'owner update and read preserved');
UPDATE user_stats SET best_score=999 WHERE id='22222222-2222-2222-2222-222222222222';
RESET ROLE;
SELECT pg_temp.check((SELECT best_score=20 FROM user_stats WHERE username='FixtureFriend'),'cross-account update denied');
UPDATE user_privacy_settings SET share_stats=true WHERE user_id='22222222-2222-2222-2222-222222222222';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=2 FROM user_stats),'accepted friend statistics opt-in honored');
SELECT pg_temp.check((SELECT count(*)=0 FROM leaderboard WHERE username='FixtureFriend'),'stats sharing does not imply leaderboard opt-in');
RESET ROLE;
UPDATE user_privacy_settings SET share_stats=false,show_on_leaderboard=true WHERE user_id='22222222-2222-2222-2222-222222222222';
SET ROLE authenticated;
SELECT pg_temp.check((SELECT count(*)=1 FROM user_stats),'leaderboard opt-in does not expose full stats');
SELECT pg_temp.check((SELECT best_score=20 AND best_streak IS NULL FROM leaderboard WHERE username='FixtureFriend'),'independent leaderboard consent preserves score but masks details');
SELECT pg_temp.check((SELECT array_agg(rank ORDER BY rank)=ARRAY[1,2]::bigint[] FROM leaderboard),'ranks calculated after privacy filter');
SELECT pg_temp.check((SELECT count(*)=0 FROM leaderboard WHERE username IN ('FixtureMissing','FixtureNull')),'missing and null consent fail closed');
DO $$ BEGIN
 BEGIN INSERT INTO friends(id,user_id,friend_id,status) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',auth.uid(),'33333333-3333-3333-3333-333333333333','accepted');
 RAISE EXCEPTION 'FAIL: forged accepted insert allowed'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: forged accepted insert denied'; END;
END $$;
INSERT INTO friends(id,user_id,friend_id,status) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',auth.uid(),'33333333-3333-3333-3333-333333333333','pending');
UPDATE friends SET status='accepted' WHERE id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
SELECT pg_temp.check((SELECT status='pending' FROM friends WHERE id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'sender cannot accept own request');
SELECT set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
DO $$ BEGIN
 BEGIN UPDATE friends SET user_id='22222222-2222-2222-2222-222222222222' WHERE id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
 RAISE EXCEPTION 'FAIL: endpoint rewrite allowed'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: recipient cannot rewrite relationship endpoints'; END;
END $$;
UPDATE friends SET status='accepted',updated_at=now() WHERE id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
SELECT pg_temp.check((SELECT status='accepted' FROM friends WHERE id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),'recipient acceptance preserved');
SELECT set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
SELECT pg_temp.check((SELECT count(*)=2 FROM user_stats),'legitimately accepted shared friend readable');
SELECT pg_temp.check((SELECT best_streak=3 FROM leaderboard WHERE username='FixtureStranger'),'consented accepted friend details readable');
RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub','',false);
SELECT pg_temp.check((SELECT count(*)=0 FROM user_stats),'anonymous full stats denied');
SELECT pg_temp.check((SELECT count(*)=0 FROM leaderboard),'anonymous leaderboard denied');
DO $$ BEGIN
 BEGIN PERFORM * FROM social_profiles; RAISE EXCEPTION 'FAIL: anonymous directory allowed';
 EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS: anonymous directory denied'; END;
END $$;
RESET ROLE;
