# Firebase monitoring — 2026-11-02

Crashlytics and Performance are integrated alongside the existing Analytics SDK,
using the existing Firebase iOS app and pinned Apple SDK 12.3.0. This is source
integration, not an App Store release or proof of received production crashes.
The ignored Firebase configuration matches the Xcode bundle and registered app.
Debug and Release share it; the console environment remains Unspecified.

## Collection and privacy

Settings now calls the existing saved preference **Analytics & Diagnostics** and
explains usage, crash and performance collection. The existing enabled default is
retained. A previously saved opt-out remains off. The separate account profile
`dataProcessingConsent` field controls other-player sharing, not this device choice.

Performance collection and instrumentation are configured before Firebase starts.
Opt-out disables data collection immediately; instrumentation changes fully apply
on the next launch. The SDK removes URL query strings, fragments and embedded
credentials from network trace URLs. No new account IDs, user content, custom logs
or free-form errors are attached to diagnostics by the app.

Crashlytics automatic uploads always remain disabled. On launch, the app considers
pending reports only if both the current preference and the previous session's
permission allow them. A reset or any opt-out invalidates the entire session's
queue, even if collection is re-enabled later. This deliberately favors privacy
over retaining every report. A delayed check also rechecks the current preference
and revision before sending. Crash capture can still occur locally while disabled;
those sessions are discarded rather than uploaded later. Already-started uploads
and previously received server data cannot be recalled by this control.

Reset clears Analytics device data/app-instance ID and unsent Crashlytics reports
without logging a reset event. Performance has no public per-event local reset
API; this is not a server-side erasure promise. Existing ad-personalization opt-out
is preserved; it does not itself disable advertising identifier collection.
Crash and performance categories are declared in the app privacy manifest. Store
privacy disclosures still need review before a release.

Debug design demos, SwiftUI previews and XCTest processes skip Firebase entirely.
No account or practice data is sent by the isolated practice preview.

## Symbols and validation

The project generates dSYMs. Its last build phase runs Firebase's symbol uploader
only for device Release builds, with the five documented input paths and script
sandboxing retained. Ordinary debug and simulator builds do not upload symbols.
An unsigned device Release archive has now compiled and generated matching dSYMs.
The upload phase passed validation and scheduled symbol transfer in the background;
receipt of those device symbols is not independently verified. Signed archive and
TestFlight upload remain blocked on existing signing/account access.

- `python3 scripts/verify-analytics/run.py`: 28 memory-only checks against the actual
  manager, monitoring controller and extracted app initializer. Covers persisted
  preference, sessions, reset, delayed callbacks, re-enable and preview isolation.
  The isolated design checkout includes one extra demo-specific check (29 total).
- Generic arm64 iOS Simulator build: passed. Main app dSYM UUIDs were checked
  against its built executables.
- An isolated simulator fixture contains no account or audio code; Analytics was
  disabled. Its original unsigned build could not access its own keychain, so
  Firebase Installations blocked Performance delivery with `-34018`.
- Rebuilding the fixture with normal ad-hoc simulator signing, the existing app
  identity and an empty entitlement template fixed that local failure. Xcode
  generated only the standard simulator application identifier. No Firebase key,
  server permission, provisioning profile or additional capability was changed.
- The corrected fixture uses the current monitoring controller. Firebase
  Performance now shows `monitoring_verification`: one sample at 306 ms, plus an
  initial `_app_start` sample at 178 ms, for synthetic version 2.0.0 (2026110201).
  Console receipt of that trace is verified; these timings are test data, not app
  benchmarks. Firebase Installations and Crashlytics settings network traces also
  appeared with 100% success for their single synthetic samples.
- The matching synthetic dSYM upload returned success. Crashlytics received one
  `ChordCrack.MonitoringVerification` nonfatal for version 2.0.0 (2026110201)
  and resolved the app frame to `ReceiptApp.swift:26`. Some simulator OS frames
  lack system symbols; app-frame symbolication is verified. No fatal crash was
  triggered. Crash-free metrics can be less complete with manual collection.
- The fixture was stopped after verification, no fixture process remains, and the
  SDK's documented `-FIRDebugDisabled` launch cleared its diagnostic logging flags.
- Existing Google Analytics reports already show automatic iOS screen, session and
  engagement events; receipt of every custom event/current app revision is not proven.

## Verification limits

The normal isolated practice preview intentionally skips Firebase. It cannot
verify receipt. The dedicated fixture establishes Performance receipt using the
same registered Firebase app and current monitoring controller, and verifies a
nonfatal report with its app frame symbolicated. It does not establish telemetry
from a released App Store binary. Signed distribution, fatal-crash reporting
and real-device behavior remain unverified. No alert policy or recipient settings were changed.

## References

- [Collection controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection)
- [Analytics reset API](https://firebase.google.com/docs/reference/swift/firebaseanalytics/api/reference/Classes/Analytics)
- [Crashlytics collection and unsent reports](https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports)
- [Crashlytics symbol configuration](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports)
- [Performance collection controls](https://firebase.google.com/docs/perf-mon/disable-sdk?platform=ios)

- [Performance troubleshooting](https://firebase.google.com/docs/perf-mon/troubleshooting?platform=ios)

- [Apple guidance on simulator signing and keychain error -34018](https://developer.apple.com/forums/thread/62847)
