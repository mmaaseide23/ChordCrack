-- Run only after explicit authorization for synthetic testing on the target.
-- No passwords, tokens, email, or permanent test accounts. Every fixture is
-- created inside this transaction and ROLLBACK removes it. Errors abort the
-- transaction; issue ROLLBACK before reusing a session after any failed probe.
-- This verifies actual database roles/RLS/RPC, not JWT issuance or HTTP routing.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '20s';
CREATE TEMP TABLE avatar_probe_ids (label text, id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO avatar_probe_ids VALUES
 ('owner','816cf408-2417-469f-90f7-2a034d719001'),
 ('friend','816cf408-2417-469f-90f7-2a034d719002'),
 ('stranger','816cf408-2417-469f-90f7-2a034d719003'),
 ('null','816cf408-2417-469f-90f7-2a034d719004'),
 ('missing','816cf408-2417-469f-90f7-2a034d719005');
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM auth.users u JOIN avatar_probe_ids f ON f.id=u.id) OR
    EXISTS (SELECT 1 FROM public.user_stats WHERE username LIKE 'AvatarProbe816cf408%') THEN
  RAISE EXCEPTION 'Fixture collision: stop without touching existing records';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='auth.users'::regclass AND NOT tgisinternal) THEN
  RAISE EXCEPTION 'Review auth triggers before creating transactional fixtures';
 END IF;
END $$;
INSERT INTO auth.users(id) SELECT id FROM avatar_probe_ids;
INSERT INTO public.user_stats(id,username,total_games)
 SELECT id,'AvatarProbe816cf408_'||label,1 FROM avatar_probe_ids;
INSERT INTO public.user_privacy_settings(user_id,share_stats,show_on_leaderboard)
 SELECT id,CASE WHEN label='null' THEN NULL ELSE false END,
           CASE WHEN label='null' THEN NULL ELSE false END
 FROM avatar_probe_ids WHERE label <> 'missing';
INSERT INTO public.friends(user_id,friend_id,status)
 VALUES ('816cf408-2417-469f-90f7-2a034d719001','816cf408-2417-469f-90f7-2a034d719002','accepted');
INSERT INTO public.profile_avatars(user_id,avatar_id)
 SELECT id,'keys' FROM avatar_probe_ids WHERE label IN ('friend','null','missing');
CREATE TEMP TABLE avatar_probe_results (check_name text, passed boolean) ON COMMIT DROP;
GRANT INSERT ON avatar_probe_results TO authenticated,anon;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','816cf408-2417-469f-90f7-2a034d719001',true);
DO $$ DECLARE n integer; BEGIN
 IF auth.uid() <> '816cf408-2417-469f-90f7-2a034d719001'::uuid THEN RAISE EXCEPTION 'Wrong synthetic owner'; END IF;
 SELECT count(*) INTO n FROM public.set_profile_avatar('guitar',auth.uid()) WHERE avatar_id='guitar' AND user_id=auth.uid();
 IF n<>1 THEN RAISE EXCEPTION 'Owner insert failed'; END IF;
 INSERT INTO avatar_probe_results VALUES ('owner RPC insert and returned identity',true);
 SELECT count(*) INTO n FROM public.set_profile_avatar('headphones',auth.uid()) WHERE avatar_id='headphones';
 IF n<>1 OR (SELECT avatar_id FROM public.profile_avatars WHERE user_id=auth.uid()) <> 'headphones' THEN RAISE EXCEPTION 'Owner update/read failed'; END IF;
 INSERT INTO avatar_probe_results VALUES ('owner update and own read',true);
 IF EXISTS (SELECT 1 FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002') THEN RAISE EXCEPTION 'Private friend leaked'; END IF;
 INSERT INTO avatar_probe_results VALUES ('accepted friend without consent hidden',true);
 UPDATE public.profile_avatars SET avatar_id='bolt' WHERE user_id='816cf408-2417-469f-90f7-2a034d719002';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'Cross-owner update succeeded'; END IF;
 INSERT INTO avatar_probe_results VALUES ('cross-owner update blocked',true);
 BEGIN
  INSERT INTO public.profile_avatars VALUES ('816cf408-2417-469f-90f7-2a034d719003','star');
  RAISE EXCEPTION 'Cross-owner insert succeeded';
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO avatar_probe_results VALUES ('cross-owner insert blocked',true); END;
 BEGIN
  PERFORM public.set_profile_avatar('star','816cf408-2417-469f-90f7-2a034d719002');
  RAISE EXCEPTION 'Mismatched identity accepted';
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO avatar_probe_results VALUES ('expected-account mismatch rejected',true); END;
 BEGIN
  PERFORM public.set_profile_avatar('unapproved-avatar',auth.uid());
  RAISE EXCEPTION 'Invalid ID accepted';
 EXCEPTION WHEN check_violation THEN INSERT INTO avatar_probe_results VALUES ('invalid avatar rejected',true); END;
 BEGIN
  UPDATE public.profile_avatars SET user_id='816cf408-2417-469f-90f7-2a034d719003' WHERE user_id=auth.uid();
  RAISE EXCEPTION 'Owner ID changed';
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO avatar_probe_results VALUES ('owner ID immutable to client',true); END;
END $$;
RESET ROLE;
UPDATE public.user_privacy_settings SET share_stats=true WHERE user_id='816cf408-2417-469f-90f7-2a034d719002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT count(*) FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002')<>1 THEN RAISE EXCEPTION 'Consenting friend missing'; END IF;
 INSERT INTO avatar_probe_results VALUES ('accepted friend plus consent visible',true);
END $$;
SELECT set_config('request.jwt.claim.sub','816cf408-2417-469f-90f7-2a034d719003',true);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002') THEN RAISE EXCEPTION 'Stranger saw friend-only avatar'; END IF;
 INSERT INTO avatar_probe_results VALUES ('stranger denied friend-only avatar',true);
 IF EXISTS (SELECT 1 FROM public.profile_avatars WHERE user_id IN ('816cf408-2417-469f-90f7-2a034d719004','816cf408-2417-469f-90f7-2a034d719005')) THEN RAISE EXCEPTION 'Null/missing consent leaked'; END IF;
 INSERT INTO avatar_probe_results VALUES ('null and missing consent hidden',true);
END $$;
RESET ROLE;
UPDATE public.user_privacy_settings SET share_stats=false WHERE user_id='816cf408-2417-469f-90f7-2a034d719002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','816cf408-2417-469f-90f7-2a034d719001',true);
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002') THEN RAISE EXCEPTION 'Friend consent revoke failed'; END IF;
 INSERT INTO avatar_probe_results VALUES ('friend consent revoke effective',true);
END $$;
RESET ROLE;
UPDATE public.user_privacy_settings SET show_on_leaderboard=true WHERE user_id='816cf408-2417-469f-90f7-2a034d719002';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','816cf408-2417-469f-90f7-2a034d719003',true);
DO $$ BEGIN
 IF (SELECT count(*) FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002')<>1 THEN RAISE EXCEPTION 'Leaderboard avatar missing'; END IF;
 IF EXISTS (SELECT 1 FROM public.user_stats WHERE id='816cf408-2417-469f-90f7-2a034d719002') THEN RAISE EXCEPTION 'Leaderboard exposed private full stats'; END IF;
 INSERT INTO avatar_probe_results VALUES ('independent leaderboard consent without full stats',true);
END $$;
RESET ROLE;
UPDATE public.user_privacy_settings SET show_on_leaderboard=false WHERE user_id='816cf408-2417-469f-90f7-2a034d719002';
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719002') THEN RAISE EXCEPTION 'Leaderboard revoke failed'; END IF;
 INSERT INTO avatar_probe_results VALUES ('leaderboard consent revoke effective',true);
END $$;
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
 BEGIN
  PERFORM avatar_id FROM public.profile_avatars WHERE user_id='816cf408-2417-469f-90f7-2a034d719001';
  RAISE EXCEPTION 'Anonymous SELECT allowed';
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO avatar_probe_results VALUES ('anonymous read denied',true); END;
 BEGIN
  PERFORM public.set_profile_avatar('guitar','816cf408-2417-469f-90f7-2a034d719001');
  RAISE EXCEPTION 'Anonymous RPC allowed';
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO avatar_probe_results VALUES ('anonymous write denied',true); END;
END $$;
RESET ROLE;
SELECT check_name,passed FROM avatar_probe_results ORDER BY check_name;
ROLLBACK;
