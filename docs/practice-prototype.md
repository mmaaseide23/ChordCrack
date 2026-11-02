# Five-round practice prototype

This is a local, disposable major/minor exercise, separate from normal practice
progress. It retains the original app colors and adds short answer feedback,
an optional light correct-answer haptic, a small string/pick response, comparison
replay after a mistake and a five-round recap. Listening never starts automatically.
Reduce Motion, the sound switch and haptic capability/preferences are respected.

Run a **Debug** build with `--design-demo --practice-prototype`, or open the
five-round button in the isolated design demo. All progress is fictional. The
exercise synthesizes its own A/E/D major/minor tones and never saves scores,
contacts account services or sends analytics. Release builds ignore demo flags;
the prototype entry is deliberately unavailable in TestFlight/release builds.

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
