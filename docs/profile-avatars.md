# Curated profile avatars and Home hierarchy

Open **Home → Profile → Change avatar**. The picker offers initials plus eight
original characters: Riff Fox, Key Cat, Beat Bunny, Melody Bird, Wave Buddy,
Bolt Bot, Star Pal and Cosmic Moth. Each has its own silhouette, expression,
musical detail and short personality line. These are original SwiftUI vector
drawings using the app's colorful palette, not copied Dot artwork or downloaded
assets. Stable stored IDs preserve existing choices as the artwork changes.
This version does not collect photos, request camera or
photo-library access, accept URLs, or create a storage bucket.

Selecting a tile previews it. **Save** changes the confirmed avatar only after a
successful server response; **Cancel** discards the draft. Selecting **Your
initial** restores the default. The picker supports Dynamic Type, named options,
selected-state announcements, and a visible checkmark. Accessibility text sizes
use a single-column list to keep names readable. Initials also cover
missing, hidden or unknown IDs; an empty username uses a person symbol.

The confirmed avatar appears on Home and Profile, and on eligible friend and
leaderboard rows. Friend requests and username search keep initials/name-only
behavior. A private profile's avatar is not added to the searchable directory.

## Privacy and persistence

- The new table stores only `user_id` and an allowlisted `avatar_id`.
- Owners can read/change their own avatar. Other authenticated users can read it
  only when existing statistics RLS or the existing consent-filtered leaderboard
  exposes that profile. This means an accepted friendship plus stats consent,
  or independent leaderboard consent with an eligible game record. Existing
  statistics, friendship, privacy and leaderboard permissions are unchanged.
- The save RPC is SECURITY INVOKER. It checks an expected account against
  `auth.uid()` before writing, so a session change cannot redirect a queued save
  to a different account. Row policies independently enforce ownership. Profile
  deletion cascades to the avatar row.
- Own-avatar state is memory-only in the client and is cleared on sign-out or
  account change. Late/cancelled operations cannot update a newer account's UI.
  Opening Profile refreshes the server value; social refreshes load newly allowed
  avatar rows without a persistent avatar cache. This is not realtime sync.
- Failed reads use initials; failed saves keep the previously confirmed choice
  and offer a retry. Missing deployment does not break existing social lists.
- `--design-demo` allows avatar selection entirely in memory, labels it as a
  preview, and performs no avatar API requests. Other account controls remain
  disabled in the preview. Restarting the preview restores initials.

## Home

Daily Riff is the single prominent green callout. Progress follows it, including
the existing level/XP and current-streak display. **More ways to practice** groups Daily Challenge
and Five-round practice as compact rows farther down. Both destinations and
their existing accessibility identifiers are preserved. The Home greeting now
points to Daily Riff, and its profile shortcut shows the chosen avatar.

## Validation and deployment

- `python3 scripts/verify-avatars/database.py`: isolated temporary PostgreSQL,
  synthetic accounts, Unix socket only. **23 checks passed**, plus unchanged
  access definitions and rollback/reapplication. Checks owner/friend/stranger/anonymous
  access, null/missing/revoked consent, expected-account mismatch, invalid IDs,
  ownership protection, profile deletion, unchanged prior access definitions,
  rollback, and reapplication.
- `python3 scripts/verify-avatars/run.py`: actual avatar model, API and store plus
  social integration with an in-memory transport. **17 checks passed** covering fallback, narrow queries,
  confirmed saves, failure/retry, preview isolation, cancellation and account
  changes. No real sign-in, photos, telemetry or audio.
- `python3 scripts/verify-social-services/run.py`: existing social privacy and
  account-scope regressions with the same in-memory transport; **33 checks passed**.
- `AvatarHomeUITests`: normal and largest text sizes on iPhone/iPad; checks Home
  order, access to Five-round practice, avatar cancel/save/reset and preview
  persistence. **All four combinations passed**; the final accessibility-list
  refinement also passed targeted reruns on both devices. Screenshots were
  reviewed at both sizes. Tests never tap playback. Daily Riff's full silent
  skip/resume/share journey passed as a regression.
- Debug and Release Simulator builds passed. Physical-device rendering and
  VoiceOver interaction have not been manually verified.

After the character-art update, the 17 avatar checks, all four native
device/text-size journeys, and Debug/Release builds passed again. The storage-ID
contract was checked explicitly, and normal/large-text screenshots were reviewed.

The additive `supabase/migrations/20261104120000_profile_avatars.sql` was applied
to production on 2026-11-04 after Michael's explicit approval and live privacy
inspection. Sixteen hosted database-role checks passed with transactional
synthetic identities; the fixtures were rolled back. Anonymous PostgREST reads
and writes were denied. Existing access definitions remained unchanged. See
[`avatar-deployment.md`](avatar-deployment.md) for evidence and the prepared
rollback. A complete signed-in app save/reload remains to be verified before
release. Rollback removes saved avatar choices; export them first if needed.
No app publication or new credentials are part of this change. Song Riff remains
disabled, with no recordings added.
