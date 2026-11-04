-- PREPARED ONLY. Not in migrations; do not apply without deployment approval.
-- Explicit per-result consent; existing privacy policies and defaults are untouched.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
CREATE TABLE public.daily_riff_results (
  user_id uuid NOT NULL REFERENCES public.user_stats(id) ON DELETE CASCADE,
  day integer NOT NULL,
  version integer NOT NULL CHECK (version = 2),
  correct boolean[] NOT NULL CHECK (cardinality(correct)=6 AND array_ndims(correct)=1
      AND array_lower(correct,1)=1 AND array_position(correct,NULL) IS NULL),
  included boolean NOT NULL DEFAULT false,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day, version)
);
ALTER TABLE public.daily_riff_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.daily_riff_results FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.daily_riff_results TO authenticated;
CREATE POLICY "Read own Daily Riff contribution" ON public.daily_riff_results
FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE FUNCTION public.submit_daily_riff(p_day integer, p_version integer, p_correct boolean[],
  p_consent boolean, p_expected_user_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE owner uuid := auth.uid(); old boolean[];
BEGIN
  IF owner IS NULL OR owner IS DISTINCT FROM p_expected_user_id THEN
    RAISE EXCEPTION 'Account changed' USING ERRCODE='42501'; END IF;
  IF p_consent IS DISTINCT FROM true OR NOT EXISTS (
    SELECT 1 FROM public.user_privacy_settings WHERE user_id=owner AND data_processing_consent IS TRUE
  ) THEN RAISE EXCEPTION 'Explicit consent required' USING ERRCODE='42501'; END IF;
  IF p_day IS DISTINCT FROM floor(extract(epoch FROM now())/86400)::integer
    OR p_version IS DISTINCT FROM 2 OR p_correct IS NULL
    OR array_length(p_correct,1) IS DISTINCT FROM 6 OR array_ndims(p_correct) IS DISTINCT FROM 1
    OR array_lower(p_correct,1) IS DISTINCT FROM 1 OR array_position(p_correct,NULL) IS NOT NULL
  THEN RAISE EXCEPTION 'Invalid daily result' USING ERRCODE='22023'; END IF;
  INSERT INTO public.daily_riff_results(user_id,day,version,correct,included)
    VALUES(owner,p_day,p_version,p_correct,true)
    ON CONFLICT (user_id,day,version) DO NOTHING;
  SELECT correct INTO old FROM public.daily_riff_results
    WHERE user_id=owner AND day=p_day AND version=p_version FOR UPDATE;
  IF old IS DISTINCT FROM p_correct THEN
    RAISE EXCEPTION 'First result already recorded' USING ERRCODE='22023'; END IF;
  UPDATE public.daily_riff_results SET included=true
    WHERE user_id=owner AND day=p_day AND version=p_version;
END $$;

CREATE FUNCTION public.withdraw_daily_riff(p_day integer, p_version integer, p_expected_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_expected_user_id THEN
    RAISE EXCEPTION 'Account changed' USING ERRCODE='42501'; END IF;
  UPDATE public.daily_riff_results SET included=false
    WHERE user_id=auth.uid() AND day=p_day AND version=p_version;
END $$;

CREATE FUNCTION public.daily_riff_summary(p_day integer, p_version integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE n integer; bands jsonb; rates jsonb; today integer := floor(extract(epoch FROM now())/86400)::integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
  IF p_day IS NULL OR p_day < today-29 OR p_day > today OR p_version IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Unsupported daily set' USING ERRCODE='22023'; END IF;
  SELECT count(*) INTO n FROM public.daily_riff_results r
    JOIN public.user_privacy_settings p ON p.user_id=r.user_id
    WHERE r.day=p_day AND r.version=p_version AND r.included AND p.data_processing_consent IS TRUE;
  IF n < 20 THEN RETURN jsonb_build_object('status','waiting','day',p_day,'version',p_version); END IF;
  WITH visible AS (
    SELECT r.correct FROM public.daily_riff_results r
    JOIN public.user_privacy_settings p ON p.user_id=r.user_id
    WHERE r.day=p_day AND r.version=p_version AND r.included AND p.data_processing_consent IS TRUE
  ), scores AS (SELECT (SELECT count(*) FROM unnest(correct) c WHERE c) AS score FROM visible),
  counts AS (SELECT b, (SELECT count(*) FROM scores WHERE score BETWEEN b*2 + CASE WHEN b>0 THEN 1 ELSE 0 END
    AND b*2+2) AS count FROM generate_series(0,2) b)
  SELECT jsonb_agg(CASE WHEN count BETWEEN 1 AND 4 THEN NULL ELSE (count/5)*5 END ORDER BY b) INTO bands FROM counts;
  WITH visible AS (
    SELECT r.correct FROM public.daily_riff_results r
    JOIN public.user_privacy_settings p ON p.user_id=r.user_id
    WHERE r.day=p_day AND r.version=p_version AND r.included AND p.data_processing_consent IS TRUE
  ) SELECT jsonb_agg(rate ORDER BY position) INTO rates FROM (
    SELECT position, ((SELECT count(*) FROM visible WHERE correct[position])*100/n/10)*10 AS rate
    FROM generate_series(1,6) position
  ) q;
  RETURN jsonb_build_object('status','available','day',p_day,'version',p_version,
    'participantsLower',(n/10)*10,'scoreBands',bands,'roundRates',rates);
END $$;

-- A scheduled privileged job is a launch prerequisite; no scheduling is installed here.
CREATE FUNCTION public.purge_expired_daily_riffs() RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
  DELETE FROM public.daily_riff_results WHERE day < floor(extract(epoch FROM now())/86400)::integer-29;
$$;
REVOKE ALL ON FUNCTION public.submit_daily_riff(integer,integer,boolean[],boolean,uuid),
  public.withdraw_daily_riff(integer,integer,uuid), public.daily_riff_summary(integer,integer),
  public.purge_expired_daily_riffs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_daily_riff(integer,integer,boolean[],boolean,uuid),
  public.withdraw_daily_riff(integer,integer,uuid), public.daily_riff_summary(integer,integer) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
