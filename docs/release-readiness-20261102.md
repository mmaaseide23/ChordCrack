# ChordCrack 2.0.0 (4) readiness

The integration preserves the existing feature baseline and original navy/green
app design, then adds the reviewed readability, accessibility, playback and
social/privacy fixes. Original local work remains recoverable in its isolated
checkout; private evidence and account fixtures are not included in this repo.

Five-round practice is available from Home in **Release and TestFlight** builds,
with comparison replay, session options and a recap. It remains separate from
account progression. See `practice-prototype.md` for its boundaries and how to try it.

## Validation

- Generic arm64 iOS Simulator build passed.
- Configured iOS device Release archive passed compilation, resource packaging
  and dSYM generation. The archive is unsigned and is not upload-ready.
- Existing app bundle identity is retained. The ignored local Supabase config is
  embedded and matches the existing project; no credential change is required.
- 33 actual social-service checks passed using memory-only transport.
- 29 Analytics/diagnostic preference, session and isolation checks passed.
- 23 synthetic PostgreSQL policy checks passed, plus rollback-catalog equivalence.
- Nine silent practice/audio scenarios passed with an in-memory player substitute.
- The original app design is retained. The new Home entry and practice options
  passed silent simulator navigation checks at standard and largest accessibility
  text sizes. Screenshots were inspected; audible UI tests were not rerun.
- The privacy diff retains consent gates, preview isolation and the narrowly
  scoped server migration. Crash/performance manifest declarations remain present.
- Source review excludes private credentials, actual disposable-account IDs and
  raw reports. Existing checked-in Firebase public configuration is unchanged.

The latest signed-in ordinary-account HTTP retest after the privacy migration
remains unverified and was deferred by the user. Real-device haptics, fatal-crash
reporting and telemetry from a released app remain unverified. The separate
synthetic fixture established Performance and nonfatal Crashlytics receipt.

## TestFlight handoff

No TestFlight upload, tester invitation or App Store release has occurred. The
archive produced here is unsigned. Complete the account, agreement and signing
readiness checks in the existing Apple Developer workflow before uploading.
Private account diagnostics are kept outside the source repository.

Restore existing signing assets, or obtain explicit approval if new signing
assets/access are required. Rebuild a signed archive from the final practice-enabled
source and verify build 4 is available before upload. Do not upload the older
build 3. Resolve export-compliance questions and any new agreements in the normal
Apple workflow.

Reference: [Apple's build upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
