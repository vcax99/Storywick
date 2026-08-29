# Configuration & Setup

Everything needed to build Storywick on a fresh Mac, run it on the simulator, and
put it on a personal iPhone.

---

## 1. Prerequisites

| Requirement | Notes |
| --- | --- |
| **macOS 15 (Sequoia) or newer** | Built and tested on 15.5. |
| **Xcode 16 or newer** | From the App Store or [developer.apple.com](https://developer.apple.com/xcode/). The Command Line Tools alone are **not** enough — the project needs the full Xcode (SwiftUI previews, the iOS SDK, Simulator). |
| **~15 GB free disk** | Xcode + one iOS simulator runtime + the app's on-device model. |
| **An iOS 17+ simulator runtime** | Usually installed with Xcode; if not, see step 2. |
| **`curl`, `python3`, `afconvert`** | All ship with macOS — only needed if you rebuild the music beds (step 5). |
| **A free Apple ID** | Only if you want to run on a physical iPhone (step 7). |

No CocoaPods, no Carthage, no Homebrew. The one third-party dependency
(`sherpa-onnx`) is a Swift Package and resolves automatically on first build.

---

## 2. One-time Xcode setup

Point the command-line tools at the full Xcode (needed for `xcodebuild` from a
terminal):

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Accept the license and install components:

```sh
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

If you have no iOS simulator runtime yet:

```sh
xcodebuild -downloadPlatform iOS
```

(Roughly a 7–9 GB download. You can also do this from Xcode →
**Settings → Components**.)

---

## 3. Get the code

```sh
git clone https://github.com/vcax99/Storywick.git
cd Storywick
```

The repo builds and runs on its own with the **System** (Apple) voice and **no
music**. The two large asset bundles below are optional but give you the full
experience.

---

## 4. Fetch the neural voice model (`KokoroModel/`, ~150 MB)

Not stored in git. Download the prebuilt Kokoro model from the `sherpa-onnx`
releases and drop it in at the repo root:

```sh
curl -L -o kokoro.tar.bz2 \
  https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2
tar xjf kokoro.tar.bz2
mv kokoro-int8-en-v0_19 KokoroModel
rm kokoro.tar.bz2
```

The folder must end up as:

```
KokoroModel/
  model.int8.onnx
  voices.bin
  tokens.txt
  espeak-ng-data/
```

Xcode bundles `KokoroModel/` as a **folder reference** (blue folder), so it's
copied into the app as-is. If it's missing, the app still runs — it just falls
back to the System voice automatically.

---

## 5. Fetch the mood music (`MoodMusic/`, ~16 MB)

Also not in git. Rebuild it from the source tracks:

```sh
./scripts/fetch-music.sh
```

This downloads 14 Kevin MacLeod tracks (CC-BY 4.0) from archive.org and transcodes
them to 48 kbps mono AAC with `afconvert`. Needs `curl` and `python3` (both stock
on macOS). Result:

```
MoodMusic/
  thriller.m4a  mystery.m4a  romance.m4a  … (14 files)
```

Missing music → moods still selectable, just silent.

---

## 6. Build & run on the simulator

**Xcode:** open `Storywick.xcodeproj`, pick an iPhone simulator in the toolbar,
press ⌘R.

**Terminal:**

```sh
xcodebuild -scheme Storywick \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build build

xcrun simctl install "iPhone 16" \
  build/Build/Products/Debug-iphonesimulator/Storywick.app
xcrun simctl launch "iPhone 16" com.bikash.Storywick -seedSample
```

`-seedSample` (DEBUG only) inserts the sample chapter so there's something in
*Recent* on first launch.

First build takes a few minutes while Swift Package Manager resolves and compiles
`sherpa-onnx` + ONNX Runtime. Subsequent builds are fast.

---

## 7. Run on a physical iPhone (free Apple ID)

1. **iPhone:** Settings → Privacy & Security → **Developer Mode** → on, reboot.
2. **Xcode → Settings → Accounts:** add your Apple ID.
3. Select the **Storywick** target → **Signing & Capabilities**:
   - **Team:** your personal team
   - **Bundle Identifier:** must be globally unique for free provisioning. If
     `com.bikash.Storywick` is taken, change it to something like
     `com.<you>.Storywick`.
4. Plug in the iPhone (or use wireless debugging), select it as the run
   destination, ⌘R. Approve the developer certificate on the phone when prompted
   (Settings → General → VPN & Device Management).

Free-provisioning limits: the app **stops working after 7 days** and must be
re-run from Xcode; max 3 sideloaded apps at once. A paid Apple Developer account
($99/yr) removes both.

---

## 8. Project layout

```
Storywick.xcodeproj/            hand-written project; target + scheme "Storywick"
Info.plist                      real plist (GENERATE_INFOPLIST_FILE = NO); UIBackgroundModes = audio
Storywick/                      all source — a synchronized folder group,
  │                             so new files are picked up without touching the project file
  StorywickApp.swift            @main entry, font registration, model container
  Views/
    RootView.swift              splash → home; owns the window colour scheme
    SplashView.swift            branded splash (always dark)
    HomeView.swift              paste box + word count + Recent list + mini-player
    ReaderView.swift            Now-Playing player: reading card, scrubber, transport
    NarrationSettingsView.swift engine picker, voice cards, speed/pitch/volume dials
    MoodPickerView.swift        mood grid + background-level slider
  Audio/
    Narrator.swift              dual-engine coordinator; playback state the UI observes
    KokoroTTS.swift             sherpa-onnx model load + blocking synth
    KokoroPlayer.swift          streaming per-sentence playback via AVAudioEngine
    VoicePreviewer.swift        standalone voice preview (both engines)
    VoiceCatalog.swift          11 Kokoro voices + narration-quality Apple voices
    Mood.swift                  25 moods → 14 music beds
    MoodMusicEngine.swift       looping AVAudioPlayer bed, volume ceiling, fades
    AudioHub.swift              single AVAudioSession owner; interruption / foreground recovery
    NowPlaying.swift            MPNowPlayingInfoCenter + MPRemoteCommandCenter
  Model/Story.swift             SwiftData model + resume / progress helpers
  Support/
    AppConfig.swift             word limit (5,000), history limit (10)
    Theme.swift                 palette, Fraunces font helper, glow modifier, AppAppearance
    AppFonts.swift              runtime font registration (CTFontManager)
    TextStats.swift             word count, sentence splitting
    StorywickMark.swift         the animated logo mark + brand gradient
    SampleData.swift            DEBUG-only sample chapter
  Resources/Fonts/Fraunces*.ttf display face (SIL OFL)
  Assets.xcassets               AppIcon, AccentColor, LaunchBackground
scripts/
  fetch-music.sh                rebuilds MoodMusic/
  make-icon.swift               regenerates the app icon PNG  (xcrun swift scripts/make-icon.swift <out.png>)
docs/screenshots/               images used by README.md
KokoroModel/                    neural TTS model  — git-ignored, see step 4
MoodMusic/                      14 mood beds      — git-ignored, see step 5
```

---

## 9. Key facts

| | |
| --- | --- |
| Xcode target / scheme | `Storywick` |
| Product | `Storywick.app` |
| Bundle identifier | `com.bikash.Storywick` |
| Display name | Storywick |
| `@main` type | `StorywickApp` |
| Deployment target | iOS 17.0 |
| Orientation | portrait, iPhone (iPad runs but isn't designed for) |
| Swift package | `sherpa-onnx` 1.13.6 (pins ONNX Runtime 1.27.1) |

---

## 10. DEBUG launch arguments

Compiled out of Release builds. Pass with `xcrun simctl launch … <flag>` or in the
scheme's **Run → Arguments**.

| Flag | Effect |
| --- | --- |
| `-seedSample` | Insert the "The Lighthouse Keeper" sample chapter if history is empty. |

---

## 11. Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `xcodebuild` fails with "unable to find utility simctl" or SDK errors | Command-line tools still point at `/Library/Developer/CommandLineTools`. Run step 2's `xcode-select -s`. |
| Asset catalog compile fails: "No available simulator runtimes" | No iOS runtime installed — `xcodebuild -downloadPlatform iOS`. |
| First build hangs on "Resolving packages" | Network. `sherpa-onnx` + ONNX Runtime are fetched once, then cached in DerivedData. |
| App speaks in a robotic voice / voice picker shows fewer options | `KokoroModel/` is missing or incomplete — the app fell back to the System engine. Redo step 4. |
| Moods do nothing (silent) | `MoodMusic/` is missing — redo step 5. |
| Can't run on device: "Failed to register bundle identifier" | `com.bikash.Storywick` is claimed by another Apple ID. Change the bundle id (step 7.3). |
| App on device stops launching after a week | Free-provisioning 7-day limit. Re-run from Xcode. |
| Simulator shows a stale app icon or old name | `xcrun simctl uninstall "iPhone 16" com.bikash.Storywick`, then reinstall. |
