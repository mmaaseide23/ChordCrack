# Daily Riff v2 validation — November 5, 2026

The final set has five rounds. The unreleased original Riff recall stage was
removed at Michael's request. Version 1's three rounds, saved first answers and
share format remain intact. Real-song guessing is still disabled with no cleared
recordings. Community statistics are a prepared design, not a live service.

## Passed

- 15 silent model/session/display checks, including both UTC boundaries,
  a year of deterministic content, v1 migration, corrupted save fallback,
  duplicate answers, interrupted playback, retry and spoiler-free shares.
- 6 iPhone 13 mini UI checks on iOS 18.6: normal and largest accessibility text,
  close/reopen, background/resume, complete five-round journeys, share sheet
  opening/dismissal, legacy results, clearly labeled community fixtures and
  access to both older practice modes.
- 3 iPad mini (A17 Pro) UI checks on iOS 18.6: normal and largest accessibility
  journeys/share dismissal, plus synthetic community and waiting layouts.
- Standard and largest-text screenshots inspected on both sizes. Decorative
  icons no longer force horizontal overflow; date, score and share controls have
  native width assertions.
- 9 existing practice/audio regressions and 15 disabled Song Riff checks. Their
  implementation was unchanged by the final recall-stage removal.
- 40 isolated PostgreSQL checks for the prepared five-round aggregate schema,
  including permissions, consent, withdrawal, retention, rollback/reapply and
  unchanged existing access. No production database was contacted.
- Configured Release simulator build for arm64 and x86_64. Existing public
  Supabase configuration is embedded in the ignored local build file. All
  Daily Riff preview arguments and `--design-demo` are absent from its binary.

The initial iPad attempt stalled before tests because its simulator service died.
That attempt was stopped, only its dedicated simulator was restarted, and the
three tests above passed on the recovered run. A sandboxed CLI check could not
start Swift's macro compiler; its authorized native rerun passed all 15 checks.
Neither failed infrastructure attempt is counted as a passing test.

## Boundaries and handoff

No audio was played through the Mac speakers. Audible timbre, physical-device
audio routes and haptics were not tested. The deferred signed-in avatar reload
check was not revisited. No real-user account or production access rule changed.

Xcode successfully opened this exact checkout after permission was renewed.
Its Apple account shows **Authentication Expired**, and the Mac has zero valid
code-signing identities and no installed provisioning profiles. No signed
archive, TestFlight upload or App Store release was produced. Reconnect the
existing Apple account and restore signing assets (or explicitly authorize any
new signing credentials), then verify available version/build numbers before
archiving and uploading. The local project currently remains version 2.0.0 (4).

Live community statistics still require the separately reviewed production
schema, privacy notice/explicit per-result consent, account-bound client transport,
include/withdraw controls, hosted permission tests and a monitored retention job.
The normal app displays an unavailable state and never submits results. See
[the deployment proposal](daily-riff-community.md) for exact data and permissions.

The requested external Claude review has not run: automatic approval review
rejected sending the Swift source, synthetic tests and undeployed SQL to Anthropic
without approval naming that payload and destination. No source was sent.
