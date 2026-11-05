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
Michael subsequently restored Apple account authentication. There is now one
valid Apple Development identity. Downloading existing manual profiles completed,
but the only profile is for `ChordCrack.ChordCrackUITests` under the configured
team `P5QS7UKW4S`; it does not cover the app bundle.

An archive attempt using existing assets, without provisioning updates, failed:
Xcode found no iOS App Development profile for
`com.michaelmaaseide.ChordCrack`. Approval for creating that specific app profile
with the existing development certificate is pending. No certificate or profile
was created by this check, and no agreement was accepted. Distribution signing
availability remains unverified; an absent local distribution certificate alone
does not rule out [Apple's cloud signing workflow](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/).

App Store Connect requires its separate web sign-in, which is prepared for user
handoff. Verify existing version/build numbers and upload permissions there before
uploading. No signed archive, TestFlight upload or App Store release was produced.
The local project currently remains version 2.0.0 (4).

Live community statistics still require the separately reviewed production
schema, privacy notice/explicit per-result consent, account-bound client transport,
include/withdraw controls, hosted permission tests and a monitored retention job.
The normal app displays an unavailable state and never submits results. See
[the deployment proposal](daily-riff-community.md) for exact data and permissions.

The initial external Claude transfer was denied by automatic approval review.
Michael then explicitly approved the nine-file source/test/SQL snapshot from
commit `f568867` for Anthropic. Its hashes were verified, and exactly one scoped
retry ran with tools, MCP, Chrome, hooks and skills disabled, from an isolated
directory. No credentials, configuration, signing assets, user records or logs
were included in the prompt.

That attempt timed out after nine minutes with empty output and diagnostics; its
process was stopped. Local authentication reports a valid first-party Claude
session, but no review findings or verdict were returned. Whether the remote
request completed is unknown. The payload was not resent, and no source changes
or fresh test claims are attributed to Claude. The passing app checks above remain
the evidence for the unchanged implementation.
