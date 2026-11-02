# Five-round practice

This is a local, disposable major/minor exercise, separate from normal practice
progress. It retains the original app colors and adds short answer feedback,
an optional light correct-answer haptic, a small string/pick response, comparison
replay after a mistake and a five-round recap. Listening never starts automatically.
Reduce Motion, the sound switch and haptic capability/preferences are respected.

Open **Home → Five-round practice**, directly below Daily Challenge, in Debug
or Release/TestFlight builds. This is a fresh major/minor session each time;
results do not affect the account or normal practice progression. It synthesizes
its own A/E/D major/minor tones and never saves scores, contacts account services
or sends analytics.

For isolated synthetic QA, run a Debug build with `--design-demo` and use the same
Home entry, or add `--practice-prototype` to open the exercise directly. Release
builds ignore both demo flags but expose the normal Home entry.

Validation includes previous inspected iPhone/iPad and accessibility-size
screens, completed practice/replay/recap and interruption journeys. Hardware
haptic feel remains untested. Audible UI tests must not be run without renewed
user permission.

Use `python3 scripts/verify-practice/run.py` for silent regression checks. It
compiles the actual audio/session/chord logic with an in-memory player substitute,
covering retry, repeated chords, late-load cancellation, partial/corrupt audio,
player startup failure, scoring, recap/restart, preferences, comparison and pitch
labels. It never launches the app or plays audio, and does not establish real
audio quality or device interruption behavior.

The two `testHomePracticeEntryOptionsAndInterruptionStaySilent` and
`testLargeTextHomePracticeEntryStaysSilent` UI checks use synthetic progress and
never tap Listen, answer or replay. They cover the Home entry, sound-off option,
background/resume, close and fresh reopen at standard and largest accessibility
text sizes. Run these named tests only while audible QA remains disallowed.
