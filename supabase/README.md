# Social privacy migration

`migrations/20261102150000_social_privacy.sql` enforces the app's separate
statistics-sharing and leaderboard preferences in PostgreSQL. It does not
modify application records.

- Owners retain their full statistics and existing write permissions.
- Full statistics require an accepted friendship and `share_stats = true` for
  another reader. Missing or null consent denies access.
- The leaderboard requires `show_on_leaderboard = true` and an authenticated
  identity. Its score/game columns remain available independently of friend
  statistics; additional statistics are masked without the corresponding access.
- `social_profiles` exposes only IDs and usernames to authenticated readers, so
  friend lookup and username availability do not require private-stat access.
- Friend inserts must be pending, only the recipient may accept/decline, and
  recipients cannot rewrite relationship IDs. This prevents forged accepted
  relationships from defeating the statistics rule.

The two projection views intentionally use owner rights with explicit filters
and a security barrier. Simply making the leaderboard an invoker view would
incorrectly couple its independent visibility preference to friend-stat access.
Existing owner/write policies and the friends-name view are preserved.

Apply the matching Swift lookup changes with this migration. Earlier clients
that search the full statistics table cannot discover private profiles. The
preflight checks reject unexpected policy/view/grant drift rather than silently
overwriting it. The transaction has short lock and statement timeouts.

The rollback in `rollback/` restores the captured original definitions and
permissions, including their previous broad reads. It is an emergency recovery
operation, not routine cleanup; coordinate the app lookup rollback first. It
does not cascade or delete application records.

Run the synthetic database checks with an already-installed PostgreSQL 17:

```sh
POSTGRES_BIN=/path/to/postgresql/bin python3 scripts/verify-social-privacy/run.py
python3 scripts/verify-social-services/run.py
```

The database runner creates a private local cluster with no TCP listener, checks
owner/friend/stranger/anonymous access, independent and missing consent, request
ownership, masking and ranks, then verifies rollback catalog equivalence. It
does not connect to Supabase. The Swift runner uses actual services with mocked
transport; neither runner sends telemetry or plays audio. Production identity
fixtures, credentials and raw integration reports are intentionally excluded.

References: [PostgreSQL policy combination and view execution](https://www.postgresql.org/docs/17/sql-createpolicy.html),
[Supabase view/RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Curated profile avatars (not deployed)

`20261104120000_profile_avatars.sql` follows the social privacy migration. It
adds only `profile_avatars(user_id, avatar_id)` and an invoker-rights RPC. Nine
allowlisted IDs represent built-in icons/initials; there are no photos, URLs,
storage buckets, new credentials, or changes to existing views/policies/grants.
Owners can change their own choice. Other authenticated readers can see it only
if the existing stats RLS or consent-filtered leaderboard exposes that profile.
The username directory and pending friend requests do not gain avatar data.

`set_profile_avatar(p_avatar_id, p_expected_user_id)` uses `auth.uid()` as its
authority and rejects an expected-account mismatch before writing. This prevents
a pending save from being applied to a newly signed-in account. Account-profile
deletion cascades to its avatar. Unknown/missing/hidden avatars fall back to
initials in the app. The app can ship without the migration, but saves will fail
honestly until it is deployed; existing game/social functions remain available.

Run `python3 scripts/verify-avatars/database.py`. The isolated PostgreSQL test
uses synthetic identities and no TCP listener or production access. It checks
23 permission/behavior cases, unchanged existing access definitions, rollback,
and reapplication. The rollback removes saved avatar choices, so export those
first if needed. It deliberately has no CASCADE for unexpected dependencies.

Deployment requires separate authorization: review current schema drift, apply
the additive migration after the privacy migration, verify RLS/RPC with ordinary
test accounts, then release the app. No production migration has been applied
by this implementation task. Reference: [PostgREST RPC and schema cache](https://docs.postgrest.org/en/v12/references/api/functions.html).
