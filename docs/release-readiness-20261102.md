# ChordCrack 2.0.0 (3) readiness

The integration preserves the existing feature baseline and original navy/green
app design, then adds the reviewed readability, accessibility, playback and
social/privacy fixes. Original local work remains recoverable in its isolated
checkout; private evidence and account fixtures are not included in this repo.

The five-round game-feel prototype is committed but remains **Debug-only** through
its isolated demo entry. It is not enabled in the Release/TestFlight interface.
See `practice-prototype.md` for its boundaries and how to try it.

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
- All 27 UI/theme source files match the previously inspected original-style
  phone/tablet/accessibility previews. Audible UI tests were not rerun.
- The privacy diff retains consent gates, preview isolation and the narrowly
  scoped server migration. Crash/performance manifest declarations remain present.
- Source review excludes private credentials, actual disposable-account IDs and
  raw reports. Existing checked-in Firebase public configuration is unchanged.

The latest signed-in ordinary-account HTTP retest after the privacy migration
remains unverified and was deferred by the user. Real-device haptics, fatal-crash
reporting and telemetry from a released app remain unverified. The separate
synthetic fixture established Performance and nonfatal Crashlytics receipt.

## TestFlight handoff

The signed archive attempt failed because Xcode could not find a matching iOS
provisioning profile. The Mac reported zero valid code-signing identities. No
provisioning-update flag, new certificate/profile, new access grant or membership
purchase was attempted. App Store Connect redirected to its sign-in page; no
authenticated dashboard or latest uploaded build number was verified.

Use the existing Apple Developer account and restore existing signing assets, or
obtain explicit approval if new signing assets/access are required. Rebuild a
signed archive and verify build 3 is available before upload. Any export-compliance
questions or new agreements remain to be resolved in the normal Apple workflow.
No TestFlight upload, tester invitation or App Store release has occurred.

Reference: [Apple's build upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
