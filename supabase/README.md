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
