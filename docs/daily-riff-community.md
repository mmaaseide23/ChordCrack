# Daily Riff community totals — prepared, not deployed

## What ships now

The five-round result page shows actual local first answers, score, round-by-round
correct/missed/skipped feedback, and spoiler-free sharing. The normal app displays
**“Community stats aren’t connected yet”** and makes **no community network request
or result upload**, including for signed-in accounts.

`DailyRiffCommunity.Summary` validates the proposed display contract.
DEBUG + `--design-demo --daily-riff-recap --daily-riff-community-fixture` shows a
synthetic layout, prominently marked **SAMPLE LAYOUT · FICTIONAL DATA**.
`--daily-riff-community-empty` demonstrates insufficient participation.
Neither fixture is reachable in Release or supplies numbers to real players.

## Exact proposed production change

`supabase/prepared/daily-riff-community/install.sql` is deliberately **outside the
migration directory**. It has only been applied to isolated, synthetic PostgreSQL.
Applying it would add one table and four functions, with these implications:

- `daily_riff_results` stores account UUID, UTC day, puzzle version (v2 only), five
  first-answer correctness flags, inclusion consent, and submission timestamp.
  No chosen answers, clips, play counts, listening time, names, location or friends.
  This is new account-linked data.
- RLS permits raw reads only by the owner. Anonymous users have no access. Friends
  and strangers cannot read another person's contribution. Clients cannot directly
  insert, update or delete rows.
- `submit_daily_riff` uses `auth.uid()`, checks the expected owner, requires explicit
  **per-result consent** and existing `data_processing_consent IS TRUE`. Missing,
  null or false processing consent fails closed. Only today's complete five-round
  result is accepted. Retries are idempotent; different subsequent scores are
  rejected. Withdraw/reinclude cannot reset the first score. Scores remain
  **self-reported**, not verified listening results. No rank, XP or prizes.
- `withdraw_daily_riff` excludes the owner's contribution from subsequent aggregate
  reads immediately, including after processing consent is revoked. Revoking the
  existing processing consent also excludes the row immediately. The private first
  result remains until expiry to prevent withdrawal becoming a score reset.
- `daily_riff_summary` is authenticated-only, scoped to a UTC day and version, and
  exposes no identities. Below **20 included players**, it returns only “waiting,”
  never exact small counts or zero placeholders. Above the threshold, participant
  counts use bands of ten; score groups (0–1, 2–3, 4–5) use bands of five; five
  per-round correct rates use ten-percentage-point bands. Score groups of 1–4 are
  suppressed; true empty groups show zero.
- `purge_expired_daily_riffs` is privileged-only and removes days older than the
  latest 30 UTC days. A monitored daily scheduler is a **launch prerequisite**;
  this script does not install or claim a running scheduler. Deleting an account's
  `user_stats` row also deletes its contribution through the foreign key.

Friend-stat sharing and public-leaderboard preferences are different purposes.
They are not implicit Daily Riff consent. Existing defaults, tables, views, policies
and grants remain unchanged. The aggregate represents **opted-in completed sets**,
not everyone who opened or played the app. Thresholds and ranges reduce disclosure;
this is not formal differential privacy and cannot guarantee anonymity against
repeated observations or external knowledge. Stored account-linked rows are private,
not anonymous.

## Approval and remaining implementation before enabling

Production is unchanged. Before deployment, confirm this exact collection, audience,
consent, retention and withdrawal behavior. Reinspect live schema/permissions and
account deletion for drift, verify compatibility, and prepare an export/rollback
plan. `rollback.sql` removes only these four functions and the table, without CASCADE.
A later rollback must also remove any separately installed retention job.

After approval: deploy and verify with synthetic identities and authenticated JWTs;
configure and test retention scheduling; update the user-facing privacy notice;
then wire explicit **include/withdraw controls and authenticated client transport**.
There is currently no client transport or automatic submission. Deploying SQL alone
will not make the UI live. Bind requests to the current owner and discard responses
on sign-out/account switch. Do not upload old device-local results automatically or
attribute shared-device results to a newly signed-in account. Require a session
started under the same account, or keep it local.

## Local verification

`python3 scripts/verify-riff-community/database.py` creates a disposable PostgreSQL
cluster with a Unix socket, no TCP listener and no Supabase credentials. It checks
owner/friend/stranger/anonymous permissions, explicit and existing consent, revoke,
input and UTC/version validation, first-result immutability, retries, aggregate math,
suppression, withdrawal/reinclude, retention and account deletion. It proves existing
policies/grants/views remain unchanged, then rolls back and reapplies.
`python3 scripts/verify-daily-riff/run.py` validates aggregate display data and daily
gameplay with a silent audio substitute. Native tests never tap playback controls.
