# Daily Riff

Open **Home → Daily Riff**. It is separate from Daily Challenge (five-round
practice with account progression) and Five-round practice (a repeatable
major/minor exercise).

Each UTC date has the same five puzzles on every device running puzzle version
2. The original first three are: major/minor, matching a mystery chord to three playable named references, and
finding the one changed position in two three-chord sequences. References make
the matching puzzle possible without absolute pitch. The switch puzzle plays
positions 1, 2, 3, then 1, 2, 3 again at equal spacing.

The two new rounds compare two chords' major/minor color and locate the one minor
chord among three. Following Michael's November 5 instruction, the original
synthesized **Riff recall stage has been removed**. There are five listening rounds
in the final v2 set. Real-song guessing remains hidden with an empty cleared catalog.
The earlier six-round v2 was an unreleased local prototype; no live catalog or
production schema was deployed from it.

Version 1's generator, answers, keys and share format remain available unchanged.
An already started or completed v1 set stays v1 for its original UTC day, including
pending feedback. Fresh sets use v2; a new day always starts v2. No old answers are
remapped or replaced, and the version is shown with the date and in shared results.
People comparing results must compare the same date **and version**.

One point per correct first answer. Unlimited replays, no timer, no rarity bonus.
Skip counts as a miss and reveals an explanation. A completed mystery listen is
required before guessing; references do not unlock an answer. Loading, player
failure, pause, backgrounding and headphone disconnection do not consume an
answer. Nothing autoplays.

The puzzle uses the existing synthesized A/Am, D/Dm and E/Em open-chord tones
from Five-round practice. It needs no recordings, download, account API or new
audio package. These are synthesized reference sounds, not recorded guitars.

Answers and pending feedback are stored immediately in a dedicated local
UserDefaults key for that date and puzzle version. Leaving and reopening keeps
the first answers; a new UTC date opens a fresh set. An already open session
keeps its original date through midnight. Results are device-local, not
server-verified or synchronized between accounts/devices, and can be lost if app
data is removed. They do not award XP, alter practice streaks or enter a leaderboard.

The native share sheet exports only the brand, UTC date, puzzle version, version-appropriate
colored result squares and score. It contains no chord names, choices or answer
positions. Sharing is user initiated. There is no web-play/deep-link promise,
remote leaderboard, automatic message, or live multiplayer feature.

## Validation

`python3 scripts/verify-daily-riff/run.py` compiles the actual model, session,
synthesizer and audio scheduling source with AVFoundation replaced by the
existing silent in-memory player. It covers a year of generated puzzles, v1 and v2
golden fixtures, the six chords' pitch classes, complete rounds, reference gates,
failure/retry, cancellation, persistence, malformed data and spoiler-free output.
`python3 scripts/verify-practice/run.py` also exercises existing practice/audio
regressions. These checks do not establish audible timbre or hardware behavior.

The `DailyRiffUITests` class uses `--design-demo` and never taps playback controls.
It exercises navigation, skip/reveal, closing/reopening, background/resume,
completion and opening (not sending through) the share sheet at standard and
largest accessibility text sizes. It also checks the existing practice entries.
The DEBUG-only `--daily-riff-recap` argument seeds a fictional 4/5 result in the
in-memory preview store; Release ignores it. Normal device results are untouched.

Select only this UI class when running the silent native checks, for example:

```sh
xcodebuild -project ChordCrack.xcodeproj -scheme ChordCrack \
  -destination 'platform=iOS Simulator,id=YOUR_REVIEW_SIMULATOR_ID' \
  -parallel-testing-enabled NO \
  -only-testing:ChordCrackUITests/DailyRiffUITests test
```

Both versioned generators are fixed, including PRNG, eligible chord order,
question order, reference patterns and answer positions. Change content only by
preserving these versions and adding another version. Golden fixtures protect both.

The end page adds a per-round breakdown and a community section with an honest
unavailable state. No totals are invented or fetched in the normal app. See
[daily-riff-community.md](daily-riff-community.md) for the tested, undeployed schema,
explicit-consent design, synthetic preview, and remaining approval/integration work.
