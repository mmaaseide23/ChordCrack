# Daily Riff prototype

Open **Home → Daily Riff**. It is separate from Daily Challenge (five-round
practice with account progression) and Five-round practice (a repeatable
major/minor exercise).

Each UTC date has the same three puzzles on every device running puzzle version
1: major/minor, matching a mystery chord to three playable named references, and
finding the one changed position in two three-chord sequences. References make
the matching puzzle possible without absolute pitch. The last puzzle plays
positions 1, 2, 3, then 1, 2, 3 again at equal spacing.

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

The native share sheet exports only the brand, UTC date, puzzle version, three
colored result squares and score. It contains no chord names, choices or answer
positions. Sharing is user initiated. There is no web-play/deep-link promise,
remote leaderboard, automatic message, or live multiplayer feature.

## Validation

`python3 scripts/verify-daily-riff/run.py` compiles the actual model, session,
synthesizer and audio scheduling source with AVFoundation replaced by the
existing silent in-memory player. It covers a year of generated puzzles, a v1
golden fixture, the six chords' pitch classes, complete rounds, reference gates,
failure/retry, cancellation, persistence, malformed data and spoiler-free output.
`python3 scripts/verify-practice/run.py` also exercises existing practice/audio
regressions. These checks do not establish audible timbre or hardware behavior.

The `DailyRiffUITests` class uses `--design-demo` and never taps playback controls.
It exercises navigation, skip/reveal, closing/reopening, background/resume,
completion and opening (not sending through) the share sheet at standard and
largest accessibility text sizes. It also checks the existing practice entries.
The DEBUG-only `--daily-riff-recap` argument seeds a fictional 2/3 result in the
in-memory preview store; Release ignores it. Normal device results are untouched.

Select only this UI class when running the silent native checks, for example:

```sh
xcodebuild -project ChordCrack.xcodeproj -scheme ChordCrack \
  -destination 'platform=iOS Simulator,id=YOUR_REVIEW_SIMULATOR_ID' \
  -parallel-testing-enabled NO \
  -only-testing:ChordCrackUITests/DailyRiffUITests test
```

The v1 generator is fixed, including its PRNG, eligible chord order, question
order and answer positions. Changing the generator requires preserving v1 or
incrementing the version, which appears in share text and persistence keys.
