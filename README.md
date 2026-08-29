# Storywick

*Where stories find a voice.*

A private iOS app that reads pasted novel chapters aloud with a natural voice and
low mood music. Personal use only — not for the App Store. (The Xcode project and
target are still named `Storywick`; the bundle id is `com.bikash.Storywick`;
the user-facing name is Storywick.)

Runs **fully offline**: on-device speech, local storage, bundled font, no network
calls anywhere. (There is no file export — resume-where-you-left-off replaces the
need for it.)

Full build plan: https://claude.ai/code/artifact/e6b86164-37c0-49ac-a8ac-422853354441

## Status

**Phase 1 — scaffold.** Done. SwiftUI, iOS 17+, portrait, SwiftData storage.

**Phase 2 — narration (Apple voices).** Done, verified on the iPhone 16 simulator.
`Narrator` wraps `AVSpeechSynthesizer`; text split into sentences for progress,
seeking, and highlighting. Player bar, active-sentence highlight, auto-scroll.

**Phase 2.5 — revisions.** Done, verified on the simulator:

- **One paste-first screen.** [HomeView](Storywick/Views/HomeView.swift): inline
  editor + word counter + a glowing "Listen" button, Recent list below.
- **History capped at `AppConfig.historyLimit` (10).** Oldest drops off.
- **Resume.** `Story.progressIndex` is saved while listening; opening a recent
  chapter starts where you stopped. Cards show a progress bar + "42% in" / "Finished".
- **Live voice / speed / pitch / volume.** The narrator speaks one sentence at a
  time, so a change is heard on the next sentence — and immediately, by re-speaking
  the current one, while playing.
- **Dark theme + toggle.** Dark-first palette, Fraunces display font (bundled,
  registered at runtime), glow on the title / play button / active line. Appearance
  toggle (System / Light / Dark) top-right, persisted.
- **Voice cards** in a 2-column grid — name, gender, accent, quality badge. Apple's
  novelty voices filtered out.
- **Vertical sliders** for Speed / Pitch / Volume (custom control).

**Phase 3 — neural voice (Kokoro).** Working, verified on the simulator:

- `sherpa-onnx` Swift package (official, `k2-fsa/sherpa-onnx` @ 1.13.6) → Kokoro via
  ONNX Runtime on CPU, so it runs on the simulator as well as devices.
- `kokoro-int8-en-v0_19` model (~129 MB) bundled as the `KokoroModel/` folder
  reference — 11 named voices, fully offline from first launch.
- [KokoroTTS](Storywick/Audio/KokoroTTS.swift) — model load + blocking synth.
- [KokoroPlayer](Storywick/Audio/KokoroPlayer.swift) — synthesises each sentence
  a couple ahead of playback on a background queue, streams through `AVAudioEngine`.
  Same highlight / scrub / resume as the Apple path.
- [Narrator](Storywick/Audio/Narrator.swift) is now dual-engine: **Natural**
  (Kokoro, default) and **System** (Apple, fallback). Settings sheet has an engine
  picker; Kokoro shows its 11 voice cards, Pitch is hidden (Kokoro has no pitch).
- First sentence shows a "Generating the voice…" spinner (~1 s on device, ~2 s on
  the simulator), then plays continuously.
- App size ≈ 190 MB.

**Phase 4 — mood music.** Working, verified on the simulator:

- **Real music beds** — 14 Kevin MacLeod tracks (CC-BY 4.0, incompetech.com), from
  archive.org, transcoded to 48 kbps mono AAC (~16 MB total), in `MoodMusic/`.
  Rebuild with `scripts/fetch-music.sh`.
- [MoodMusicEngine](Storywick/Audio/MoodMusicEngine.swift) — `AVAudioPlayer` on a
  gapless loop, hard volume ceiling (0.22) so it's always under the voice, fades
  in/out for pause and stop. A "Background level" slider trims within the ceiling.
- [Mood](Storywick/Audio/Mood.swift) — all 25 mood names selectable + None,
  mapped onto the 14 beds (several names share one, e.g. Thriller/Action;
  Fantasy and Meditative use the Indian-flavoured Vadodara tracks).
- Per-chapter: `Story.mood` is saved. Picked from the music-note button in the
  reader ([MoodPickerView](Storywick/Views/MoodPickerView.swift)).

**Audio reliability (Phase 4c):**

- [AudioHub](Storywick/Audio/AudioHub.swift) — one owner of the `AVAudioSession`.
  Configures it once, never deactivates it, and re-asserts playback after an
  interruption (call, timer) or when the app returns to the foreground. This is
  what stops the music bed from silently dropping out.
- **Instant mood switching:** all 14 beds are decoded and prepared at launch
  (background queue), so `setMood` just grabs the ready player and fades it in
  over ~0.3 s — no on-the-spot file load, no 1.4 s ramp.
- `MoodMusicEngine` now has an `AVAudioPlayerDelegate` (recovers from decode
  errors and interruptions) and an `ensurePlaying()` the hub calls.
- **Gapless Kokoro:** the neural player synthesises up to 8 sentences ahead and
  schedules each buffer on the node the moment it's ready, so the node never runs
  dry between sentences. Each clip is silence-trimmed with a ~100 ms beat, so
  sentences butt together instead of lurching.
- **Apple path** queues every remaining sentence into the synthesiser at once
  (was one-at-a-time, which left a round-trip gap between each).
- The reader only auto-scrolls when the active *paragraph* changes, not on every
  sentence.

**Background / lock-screen playback:**

- `UIBackgroundModes = audio` (real `Info.plist` now — `GENERATE_INFOPLIST_FILE`
  is off), `AVAudioSession` `.playback`.
- [NowPlaying](Storywick/Audio/NowPlaying.swift) — `MPNowPlayingInfoCenter`
  (chapter title, sentence position) + `MPRemoteCommandCenter` (play/pause,
  next/previous → skip a sentence). Works from the lock screen, Control Center,
  and headphone controls.
- The `Narrator` is a single app-level instance (`@Environment`), so narration
  keeps playing when you navigate back to the home screen — a mini "Now narrating"
  bar there reopens the reader or pauses.

**Dark theme** reworked to the "Emerald Glow" palette (emerald + lime spark on
near-black); light theme is the "Emerald" palette (emerald on #F6F9F7 paper). The
appearance toggle is **two states only** — a sun and a moon, no System option.

**Phase 5 — player screen + branding.** Done, verified on the simulator:

- **Now-Playing-style reader.** [ReaderView](Storywick/Views/ReaderView.swift)
  is an Apple-Music-style player: chapter title up top, a card showing the chapter
  text with the current sentence spotlit (rest dimmed, lyrics-style) and a lime
  rail on the active paragraph, then the now-playing line, a scrubber, a big
  emerald play/pause with skip buttons, and Mood / Voice buttons. Reading text is
  smaller (15 pt serif) by default.
- **Light + dark.** The reader follows the app theme — emerald wash over near-black
  in dark, over pale mint in light — with a white/tinted reading card that lifts
  off the background. `RootView` owns the window colour scheme (`Theme.*` resolves
  correctly once nothing forces a scheme); it forces dark only for the splash.
- **Time scrubber.** A custom progress bar (`PlaybackScrubber`) with an estimated
  **elapsed / total clock** (`0:46 / 1:29`) that ticks each second, from a
  per-sentence duration estimate (word count ÷ speaking rate, scaled by the speed
  slider). Its thumb is the Storywick mark (`SpinningMark`), turning clockwise
  while playback runs and frozen when paused / stopped / dragging. Dragging seeks
  to the nearest sentence. In its own subview so the reading card doesn't redraw
  on every tick.
- **Animated logo** (`StorywickMark(animated:)`) — the waveform bars wobble. Shown
  on the home title, the splash, and the reader's nav bar.

## Branding

- Name **Storywick** — `CFBundleDisplayName` in `Info.plist`, the home-screen
  title, and the now-playing artist.
- Logo: `Support/StorywickMark.swift` — waveform bars flowing into a play
  triangle, one lime→green→teal gradient (`Theme.brandGradient` /
  `brandLime` `#A3E635`, `brandGreen` `#10B981`, `brandTeal` `#06B6D4`).
  Shown on the home screen next to the wordmark. The app icon is generated by
  `scripts/make-icon.swift` into `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
  (near-black + glow).
- Splash: `Views/SplashView.swift` (animated logo + wordmark + slogan + "Powered
  By" / "Bikash", ~4 s) over a `LaunchBackground` colour-only OS launch screen.
  Wired via `Views/RootView.swift`. **Always dark**, whatever the app theme.

## Project layout

```
Storywick/
  StorywickApp.swift                app entry, font registration
  Views/RootView.swift               splash -> home; owns the window colour scheme
  Views/SplashView.swift             branded splash
  Support/StorywickMark.swift        logo mark
  Model/Story.swift                   SwiftData model + resume/progress helpers
  Support/AppConfig.swift             word limit, history limit
  Support/TextStats.swift             word count, sentence splitting
  Support/Theme.swift                 palette, fonts, glow, AppAppearance
  Support/AppFonts.swift              runtime font registration
  Support/SampleData.swift            DEBUG sample chapter
  Audio/Narrator.swift                dual-engine coordinator (Kokoro / Apple)
  Audio/KokoroTTS.swift               sherpa-onnx model load + synth
  Audio/KokoroPlayer.swift            streaming per-sentence playback via AVAudioEngine
  Audio/VoiceCatalog.swift            Kokoro voices + narration-quality Apple voices
  Audio/Mood.swift                    25 moods -> 14 music beds
  Audio/MoodMusicEngine.swift         looping AVAudioPlayer bed
  Audio/NowPlaying.swift              lock-screen info + remote commands
  Views/HomeView.swift                paste + counter + Recent + mini player
  Views/ReaderView.swift              Now-Playing-style player + time scrubber
  Views/NarrationSettingsView.swift   engine picker, voice cards, vertical dials
  Views/MoodPickerView.swift          mood grid + background level slider
  Resources/Fonts/Fraunces*.ttf       display font (SIL OFL)
  Assets.xcassets                     AppIcon (placeholder), AccentColor
Info.plist                            real plist (UIBackgroundModes = audio)
KokoroModel/                          neural TTS model (git-ignored, ~152 MB)
  model.int8.onnx, voices.bin, tokens.txt, espeak-ng-data/
MoodMusic/                            14 mood beds (git-ignored, ~16 MB)
scripts/fetch-music.sh                rebuilds MoodMusic/
```

The Kokoro model is not in git. Re-download:

```sh
curl -L -o k.tar.bz2 https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2
tar xjf k.tar.bz2 && mv kokoro-int8-en-v0_19 KokoroModel
```

## Offline

Nothing in the app talks to the network. `AVSpeechSynthesizer`, SwiftData, and the
bundled font all work with no connection. On a real device, Apple's *enhanced* /
*Siri* voices need a one-time download in Settings before they work offline; the
default voices need nothing. Phase 3's Kokoro model ships inside the app, so the
human voice is offline from first launch.

## Build & run

Open `Storywick.xcodeproj` in Xcode, pick an iPhone simulator, ⌘R. Terminal:

```sh
xcodebuild -project Storywick.xcodeproj -scheme Storywick \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

If Xcode was just installed:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -downloadPlatform iOS
```

### DEBUG launch arguments

Compiled out of release builds.

| Flag | Effect |
|---|---|
| `-seedSample` | Insert the "The Lighthouse Keeper" sample chapter if history is empty |

## Defaults

New chapters start with the **Bella** neural voice and the **Mystery** mood bed.
Nothing auto-opens — the voice and background sheets are only reached from their
buttons in the player bar.
