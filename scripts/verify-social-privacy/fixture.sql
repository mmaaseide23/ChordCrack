-- Synthetic local database only. Never run this file against Supabase.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
CREATE TABLE public.user_stats (
 id uuid PRIMARY KEY, username text NOT NULL UNIQUE, total_games integer NOT NULL DEFAULT 0,
 best_score integer NOT NULL DEFAULT 0, best_streak integer NOT NULL DEFAULT 0,
 average_score numeric(5,2) NOT NULL DEFAULT 0, total_correct integer NOT NULL DEFAULT 0,
 total_questions integer NOT NULL DEFAULT 0
);
CREATE TABLE public.user_privacy_settings (
 user_id uuid PRIMARY KEY REFERENCES user_stats(id), share_stats boolean,
 show_on_leaderboard boolean, allow_friend_requests boolean, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.friends (
 id uuid PRIMARY KEY, user_id uuid REFERENCES user_stats(id), friend_id uuid REFERENCES user_stats(id),
 status text, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(), UNIQUE(user_id,friend_id)
);
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_privacy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
GRANT ALL ON user_stats,user_privacy_settings,friends TO anon,authenticated;
CREATE POLICY "Public can view user stats for leaderboard and friends" ON user_stats FOR SELECT TO authenticated USING(true);
CREATE POLICY "Users can view own stats" ON user_stats FOR SELECT TO authenticated USING(auth.uid()=id);
CREATE POLICY "Users can insert own stats" ON user_stats FOR INSERT TO authenticated WITH CHECK(auth.uid()=id);
CREATE POLICY "Users can update own stats" ON user_stats FOR UPDATE TO authenticated USING(auth.uid()=id) WITH CHECK(auth.uid()=id);
CREATE POLICY "Public can view privacy settings for features" ON user_privacy_settings FOR SELECT TO authenticated USING(true);
CREATE POLICY "Users can update own privacy settings" ON user_privacy_settings FOR UPDATE TO authenticated USING(auth.uid()=user_id) WITH CHECK(auth.uid()=user_id);
CREATE POLICY "Users can insert friend requests" ON friends FOR INSERT TO authenticated WITH CHECK(user_id=auth.uid());
CREATE POLICY "Users can update their friend relationships" ON friends FOR UPDATE TO authenticated USING(user_id=auth.uid() OR friend_id=auth.uid());
CREATE POLICY "Users can view their own friends" ON friends FOR SELECT TO authenticated USING(user_id=auth.uid() OR friend_id=auth.uid());
CREATE VIEW leaderboard AS SELECT row_number() OVER (ORDER BY best_score DESC,total_games DESC) AS rank,
 id AS user_id,username,best_score,total_games,best_streak,average_score,total_correct,total_questions
 FROM user_stats us WHERE total_games>0 ORDER BY best_score DESC,total_games DESC;
CREATE VIEW friends_with_usernames AS SELECT f.*, u1.username AS requester_username,u2.username AS recipient_username
 FROM friends f LEFT JOIN user_stats u1 ON f.user_id=u1.id LEFT JOIN user_stats u2 ON f.friend_id=u2.id;
GRANT ALL ON leaderboard,friends_with_usernames TO anon,authenticated;
INSERT INTO user_stats VALUES
 ('11111111-1111-1111-1111-111111111111','FixtureOwner',1,10,1,10,1,5),
 ('22222222-2222-2222-2222-222222222222','FixtureFriend',1,20,2,20,2,5),
 ('33333333-3333-3333-3333-333333333333','FixtureStranger',1,30,3,30,3,5),
 ('44444444-4444-4444-4444-444444444444','FixtureMissing',1,40,4,40,4,5),
 ('55555555-5555-5555-5555-555555555555','FixtureNull',1,50,5,50,5,5);
INSERT INTO user_privacy_settings(user_id,share_stats,show_on_leaderboard,allow_friend_requests) VALUES
 ('11111111-1111-1111-1111-111111111111',false,false,true),
 ('22222222-2222-2222-2222-222222222222',false,false,true),
 ('33333333-3333-3333-3333-333333333333',true,true,true),
 ('55555555-5555-5555-5555-555555555555',null,null,true);
INSERT INTO friends(id,user_id,friend_id,status) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','accepted');
