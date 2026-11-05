# Song Riff: disabled prototype

Song Riff is a separate one-question daily song-guessing round. It is **disabled**,
has **zero approved recordings**, and has no Home/menu entry. There is no working
real-song catalog, streaming integration, or downloadable audio in this change.
Daily Riff now uses five-round v2 for new sets; v1 generation and saved results
remain intact. The unreleased synthesized Riff recall stage was removed at the
user's request. No real-song replacement or cleared catalog has been added. No new launch argument can enable Song Riff.

## Implemented boundary

- `SongClipCatalog` defines exact asset identity (bundle filename and SHA-256),
  clip interval, performer, and separate composition, arrangement, and recording
  evidence. Reviews record territory, date/expiry, reviewer, commercial quiz use,
  bundled excerpt use, maximum excerpt length, and permission to defer credits
  until the answer reveal. Licensed evidence also requires attribution, a license
  URL, and a modification notice. These records document a review; they do not
  establish rights by themselves.
- `SongRiffFeature.isEnabled` is false and `SongClipCatalog.current` is empty.
  Production rejects all synthetic fixtures. DEBUG's explicit `syntheticTests`
  catalog use exists for silent tests only; the native backend rejects fixtures
  in all builds. Fixture names explicitly say they are not songs.
- After clearance, a sorted catalog and UTC date choose the same song and three
  title choices for everyone on that catalog version. An unsupported territory
  gets an unavailable result, not a substitute song. The caller must resolve an
  actual supported territory; the implementation does not assume locale proves
  location. An open round retains its original date through midnight.
- `SongClipPlayer` accepts only a catalog-produced round, rechecks rights before
  and after preparation, and cancels stale generations. The iOS backend reads only
  a bundled asset, checks its hash, and uses AVAudioPlayerNode's
  [scheduled file segment API](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulesegment(_:startingframe:framecount:at:completioncallbacktype:completionhandler:)).
  Start/end are rounded inward to audio frames; invalid or out-of-file intervals
  fail closed. The native `.dataPlayedBack` callback unlocks answers. A watchdog
  handles missing callbacks; it is not the mechanism that bounds the clip.
- `SongGuessingSession` implements listen → guess → reveal, one first answer,
  retry after failure, pause/stop, replay, and spoiler-free date/version/score
  sharing. It stores answers under `songRiff.v1.catalog<version>.<UTC day>`, separate
  from `dailyRiff.*`. The unexposed SwiftUI view includes credits/source/license
  links after reveal and stops on background, interruption, or headphone removal.
  Nothing autoplays. There is no XP, leaderboard, account sync, or backend write.

To enable a future reviewed version, maintainers must add cleared, hash-pinned
assets and manifests, preserve old catalog versions for old saved results,
provide a supported territory, and deliberately wire the screen and release
gate. Changing title choices or selected clips requires a new catalog version.
The current deterministic rotation is a prototype; a larger curated catalog and
editorial schedule would improve replay variety. Bundled files and choices are
inspectable, so this does not promise anti-cheat protection.

## Silent validation

Run `python3 scripts/verify-song-riff/run.py` on macOS with Xcode installed. It
compiles the actual catalog/player/session with a state-only fake backend and
synthetic metadata. It never imports AVFoundation, reads a recording, or creates
audio bytes. Its 15 checks cover the release gate, fixture isolation, all rights
layers and usage grants, territory/expiry, malformed assets, license attribution,
UTC/catalog identity, inward frame bounds, answer gates, persistence isolation,
spoiler-free sharing, failure/retry, cancellation races, expiry during preparation,
cleanup, and timeout/late completion.

`python3 scripts/verify-daily-riff/run.py` checks the existing v1 golden puzzle and
saved-result behavior with a silent audio substitute. Debug and Release Simulator
builds compile the native backend and the hidden UI. Audible output, real asset
decoding, native timing on hardware, and headphone routing still require testing
with headphones after clearance. Do not run unrelated native audio tests under
the no-speaker-playback constraint.

Validation completed on 2026-11-04: all 15 Song Riff checks and all 11 Daily Riff
v1 checks passed. The final Debug build and two existing iPhone UI regressions
(full skip/resume/share journey and both practice entries) passed, as did the
Release Simulator build. No native playback controls were tapped.

## Recording research — 2026-11-04

Only metadata/source pages were inspected. No recording was downloaded, bundled,
or played. The following are recognizable classical/ragtime works worth checking;
they do not provide a modern-pop catalog. A composition's age alone does not clear
a recording or a later arrangement: the U.S. Copyright Office describes
[the separate composition and sound-recording rights](https://www.copyright.gov/circs/circ56a.pdf).

| Work / exact recording lead | Verified source evidence | Remaining review / attribution |
| --- | --- | --- |
| **The Entertainer — IE, September 2007** | [The performer's Commons release](https://commons.wikimedia.org/wiki/File:The_Entertainer_-_Scott_Joplin.ogg) dedicates the performance to the public domain, with fallback unrestricted permission. It identifies IE, the keyboard, recording date, and score. [That Mutopia score](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=263) identifies a reproduction of the original 1902 piano edition as public domain. | Strongest composition/score/recording chain found. The source documents U.S. and life-plus-100-or-less composition status, not a universal legal opinion. Confirm launch territories and exact file revision. Credit Joplin and IE and record conversion/excerpt changes as provenance, even where attribution is not required. No app approval or checksum has been recorded. |
| **Moonlight Sonata, first movement — Paul Pitman / Musopen** | [Commons' recording page](https://commons.wikimedia.org/wiki/File:Ludwig_van_Beethoven_-_sonata_no._14_in_c_sharp_minor_%27moonlight%27,_op._27_no._2_-_i._adagio_sostenuto.ogg) separates composition and recording rights and displays Wikimedia VRT permission ticket **2008012110017088**. It says correspondence confirming the rights holder's release was reviewed by a volunteer. | This is independent documentary corroboration, not access to the private correspondence itself. The page also carries attribution language: retain a Musopen URL and performer credit. Confirm exact arrangement/edition, U.S. basis and launch territories, and that reveal-time attribution is sufficient. The historical Musopen source URL currently returned 404. |
| **Für Elise — German Kitkin, published by Lev Kitkin, 2024; IMSLP #929281** | [The specific performance listing](https://imslp.org/wiki/F%C3%BCr_Elise,_WoO_59_(Beethoven,_Ludwig_van)) labels this recording CC BY 4.0. [Mutopia separately documents](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=931) the original piano composition and an 1888 public-domain edition. | The recording listing does not establish that the performer used that edition or independently prove the publisher's authority. The individual file metadata page hit a bot check. Confirm both before importing. CC BY 4.0 needs creator credit, source/license links and a changes notice; review App Store distribution restrictions. Other performances on the same IMSLP page have NC/ND licenses and are not substitutes. |
| **Gymnopédie No. 1 — Teknopazzo** | [Commons metadata](https://commons.wikimedia.org/wiki/File:Gymnopedie_No._1..ogg) states own work and CC0; it identifies the composition's 1888 publication. | Weaker provenance: no clearly documented arrangement/edition or detailed performer/recording chain. The date field is the composition date, not evidence of the recording's age. Hold until those gaps and territories are resolved. |

The [CC BY 4.0 terms](https://creativecommons.org/licenses/by/4.0/) permit commercial
sharing/adaptation subject to credit, license links, change indications, and no
additional legal/technological restrictions. Public-domain dedications and
territorial copyright conclusions should still be checked for the intended
countries and exact recording. No automatic "worldwide" approval is populated.

The existing ChordCrack asset repository's
[CC BY 4.0 license](https://github.com/mmaaseide23/ChordCrack_Assets/blob/main/LICENSE)
covers its individual guitar-note samples. Those are not real-song recordings.
The app's existing synthesizer likewise supplies chord reference sounds, not a
licensed song catalog. This change does not repurpose either as pretend songs.

**Current blocker:** a reviewed set of at least three exact recordings, including
arrangement provenance, territory, attribution timing and app-distribution terms.
The catalog remains empty until that review is complete. Provider clips such as
Apple Music previews need their own expressly permitted quiz architecture; this
bundled-file adapter does not assume such permission or download provider audio.
