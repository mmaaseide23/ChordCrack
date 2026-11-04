# Avatar production deployment — 2026-11-04

Michael explicitly approved the avatar migration and synthetic-account testing.
The prepared `20261104120000_profile_avatars.sql` was applied to ChordCrack's
production Supabase project through its signed-in SQL editor. Its source SHA-256
was `22335014823383ca9d018743817cc20c362e9d99d816eecb90fd7f01dc3cb9a6`.
The transaction returned success. No earlier privacy migration was reapplied.

Before deployment, read-only catalog inspection verified the live owner/friend
statistics policies, independent leaderboard consent, username-only directory,
view security barriers, grants, foreign keys and triggers. These matched the
avatar migration's assumptions. Avatar objects did not exist. There were no
non-internal `auth.users` triggers. Only timestamp-update triggers existed on
the relevant application tables.

The fingerprint of existing public table/view definitions, RLS flags, owners,
policies, table grants and column grants was
`2ae3b37d1e76a3c3edb3ce8ea8ef7857` both before and after deployment/testing.
The avatar objects are deliberately excluded from that comparison. No existing
profile, friendship, statistics or leaderboard access was changed.

## Live validation

`scripts/verify-avatars/live-permissions.sql` passed all **16 checks** against
the actual hosted database. It creates five collision-checked synthetic
identities inside one transaction, switches to the real `authenticated`/`anon`
roles, and ends with `ROLLBACK`. No passwords, tokens, email addresses or durable
test accounts are created. The same probe passed a local dry run first:

```sh
python3 scripts/verify-avatars/live-dry-run.py
```

Checks cover owner insert/update/read, cross-owner insert/update denial,
immutable owner ID, expected-account mismatch, invalid avatar IDs, accepted
friends with and without consent, strangers, missing/null consent, independent
leaderboard visibility, both consent revocations and anonymous read/write denial.

The read-only postcheck confirmed all synthetic identities were absent, avatar
RLS remained enabled, the RPC remained SECURITY INVOKER, and anonymous read/RPC
privileges were absent. The live anonymous PostgREST GET (zero-row projection)
and RPC POST both returned HTTP 401 / SQLSTATE 42501 using the app's existing
public anonymous key. No real account rows were returned or logged.

These are hosted database role tests plus anonymous HTTP tests. **Signed-in
JWT issuance and a complete authenticated iOS → PostgREST save/reload have not
been exercised.** The native avatar tests use the clearly labeled in-memory
preview. No service credential was obtained, and no permanent test login was
created. A controlled signed-in smoke test remains before app release.

## Prepared rollback

`supabase/rollback/20261104120000_profile_avatars.sql` drops only
`set_profile_avatar(text, uuid)` and `profile_avatars`, then reloads the PostgREST
schema cache. It uses one transaction, a five-second lock timeout, a thirty-second
statement timeout, and no CASCADE. Its rollback/reapplication passed the earlier
isolated PostgreSQL checks. It was prepared before deployment and was **not run
against production**, because deployment and validation passed.

If rollback becomes necessary after users save choices, preserve those choices
first. Rollback removes avatar choices; it does not alter existing statistics,
privacy, friendships or leaderboard definitions. App publication is separate.
