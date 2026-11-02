# Monitoring verification — 2026-11-02

Analytics is configured; crash and performance monitoring are not yet integrated.

| Check | Evidence / limit |
| --- | --- |
| App configuration | The locally supplied Firebase configuration matches the Xcode bundle and registered Firebase iOS app. Debug and Release currently share that configuration; the console environment is Unspecified. Config files remain excluded from Git. |
| Analytics | Firebase Apple SDK 12.3.0, Analytics and AnalyticsCore linked. The project's Google Analytics report for Oct 5–Nov 1 shows received automatic iOS screen/session/engagement events. This does not validate this source revision or every custom game event. |
| Crashlytics | No linked Crashlytics product, initialization or symbol-upload build phase. Console still shows Add SDK. No received crash report verified. Release dSYM generation alone is insufficient. |
| Performance | No linked Performance product or instrumentation. Console still shows Add SDK. No received traces verified. |
| Preferences | Startup now honors the same saved Analytics preference as Settings. The existing enabled default is retained; profile data-processing consent is separate and is not an Analytics consent gate. |
| Reset | Uses the SDK device-data/app-instance-ID reset and does not emit a reset event. This is not a server-side deletion promise. |
| Sessions | Firebase owns the reserved session_start event. Custom duration tracking ends once and excludes disabled intervals. |
| Ads / privacy | Existing ad-personalization opt-out is preserved. That property does not disable advertising identifier collection. Analytics and AnalyticsCore are both linked; SDK manifests and final store disclosures require review before changing collection. |

Validation: `python3 scripts/verify-analytics/run.py` compiles actual manager code and
app initializer with in-memory Firebase/preferences/clock spies. No real SDK,
telemetry, account container, simulator or audio is used. The isolated application
also passed a generic iOS Simulator build. Local preview builds skip Firebase.

Further monitoring setup requires an explicit choice about Crashlytics and
Performance collection, consent and environments. No SDK was added, collection
enabled, keys/grants created, production telemetry generated or deliberate crash
performed during this audit. A future Crashlytics receipt check must include its
symbol upload and a separately authorized synthetic test crash.

References:
- [Collection controls and advertising identifiers](https://firebase.google.com/docs/analytics/ios/configure-data-collection)
- [Analytics API: reserved events and reset](https://firebase.google.com/docs/reference/swift/firebaseanalytics/api/reference/Classes/Analytics)
- [Crashlytics Apple setup and symbols](https://firebase.google.com/docs/crashlytics/ios/get-started)
- [Performance Monitoring](https://firebase.google.com/docs/perf-mon)
