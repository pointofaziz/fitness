# Lift Log

A native, offline SwiftUI iPhone workout log for the exact four-day programme in [the brief](docs/OriginalBrief.md). **The complete Xcode project is `LiftLog.xcodeproj`.** This repository was implemented in Codex Cloud on Linux for transfer to a Mac, as requested. No web app, third-party libraries, accounts or services.

**Verification status:** 31 Foundation core tests passed on Linux. The [11 October cloud Mac run](https://github.com/pointofaziz/fitness/actions/runs/38145061087) successfully compiled the native iOS app for Intel and Apple silicon simulators, installed and launched it, and captured a screenshot. Its combined unit/UI test step failed (exit 65), so those suites are not verified as passing. The run provides the simulator app and diagnostic artifacts. Physical-iPhone installation and behavior remain unverified. See [the verification record](docs/Verification.md).

## Download and open on your Mac

1. Open [the repository](https://github.com/pointofaziz/fitness) and choose **Code → Download ZIP**. Double-click the downloaded ZIP to extract `fitness-main`. It includes the complete source project and tests. GitHub's source ZIP does not contain Git history; use `git clone https://github.com/pointofaziz/fitness.git` if you need the commits.
2. Move the extracted folder somewhere permanent, for example `~/Developer/LiftLog`.
3. Install a current stable **Xcode** from the Mac App Store or [Apple Developer downloads](https://developer.apple.com/download/all/). Xcode 15+ can build the iOS 17 deployment baseline; prefer the current stable Xcode that supports your Mac's macOS and your iPhone's iOS. Open Xcode once, accept its licence and let it install components.
4. In Xcode → Settings → Platforms/Components (label varies by version), download an iOS simulator runtime. Use a runtime at iOS 17 or later.
5. Open `LiftLog.xcodeproj`, **not `Package.swift`**. Select the shared **LiftLog** scheme and an available iPhone simulator. Press **⌘R** to build and run. Simulator use requires no paid membership or signing team.
6. Press **⌘U** to run the core + native persistence tests and UI journeys. Repeat on a compact iPhone SE (3rd generation) if your installed runtime supports it, and a standard iPhone. Otherwise install a compatible older runtime for the compact-size check.

Command-line equivalent, without changing the Mac's global Xcode selection:

```bash
cd ~/Developer/LiftLog
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun simctl list devices available
# Copy an available iPhone simulator UUID from that list:
IOS_SIMULATOR_ID='PASTE-SIMULATOR-UUID-HERE' ./scripts/test-ios.sh
```

The test script creates a new `.xcresult` under `/tmp`; open that file in Xcode to inspect failures and UI evidence. `DEVELOPER_DIR` is scoped to this shell. No simulator name or SDK installation is assumed.

## Build on a Mac in the cloud

Open [GitHub Actions](https://github.com/pointofaziz/fitness/actions/workflows/ios.yml). The **Build iPhone app in the cloud** workflow runs automatically on pushes to `main`; you can also click **Run workflow**. It uses a GitHub-hosted Mac, compiles a universal iPhone simulator app, captures an actual app screenshot, and runs the unit/UI tests. A workflow definition is not proof of a successful run: check the current result and logs.

After a run, open it and find **Artifacts → LiftLog-Simulator-and-Test-Results**. Sign into GitHub if downloading requires it. Extract the artifact, then extract its `LiftLog-Simulator.zip`. Double-click **Run-LiftLog.command** in the `simulator-download` folder to automatically select an iPhone simulator, install the prebuilt app and open it. You still need Xcode and an iOS 17+ simulator runtime on your Mac, but no local compilation or signing team is needed. If macOS blocks the command, right-click → Open, or open Terminal in that folder and run `bash Run-LiftLog.command`.

The artifact also contains `Simulator-preview.png`, build/test logs and, when tests reach execution, an `.xcresult` bundle. If the build fails there will be no app ZIP; read `build.log`. If tests fail after building, the app ZIP can still exist, but the workflow must not be described as fully verified. The simulator binary cannot be installed on a physical iPhone: that requires a device build and your Apple signing team as described below. Artifact downloads expire after 14 days; rerun the workflow if necessary.

## Install on your own iPhone

1. In Xcode → Settings → Accounts, add your Apple Account directly in Xcode. Never place credentials in this repository or chat.
2. Open the project settings → **LiftLog target → Signing & Capabilities**. Enable automatic signing and select your Personal Team (or paid team).
3. Change `LIFTLOG_BUNDLE_ID` in `LiftLog/AppIdentity.xcconfig` to a unique identifier such as `com.yourname.liftlog.personal`. The test identifiers derive from this setting. If Xcode offers to manage signing for test targets, use the same team.
4. Connect the iPhone by USB, unlock it, and accept **Trust This Computer** on the phone. In iPhone Settings → Privacy & Security, enable **Developer Mode** if required, restart and confirm. Xcode may need to finish preparing the device.
5. Select your iPhone as the run destination and press **⌘R**. Resolve signing prompts in Xcode. If iOS asks to trust the developer profile, follow the prompt in Settings → General → VPN & Device Management.
6. Run the physical-device checklist in `docs/Verification.md`, especially force-quit recovery, airplane mode, timer permissions and backups. A simulator result cannot verify phone signing, notification delivery or installation.

A free Apple Account / Personal Team supports personal device testing, with limits rather than a permanent installation. Apple's published Personal Team limits include provisioning profiles expiring after **7 days**, up to **10 App IDs** and **3 test devices per platform** within the applicable seven-day period; you may need to reconnect and rebuild/reprovision. Export JSON before signing or installation changes; do not delete the app to renew signing. Paid membership is not required for simulator development and is not added by this project. No TestFlight or App Store publication is performed.

Official references: [membership comparison and Personal Team limits](https://developer.apple.com/support/compare-memberships/), [running on a device](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device), [enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), [SwiftData migration plans](https://developer.apple.com/documentation/swiftdata/schemamigrationplan), [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility). The cloud network rejected live retrieval from `developer.apple.com`; verify the current signing limits and Xcode requirements at these official links on your Mac.

## Log your first workout

1. Open **Train**. The schedule begins Monday **12 October 2026, Upper A**. Rest days show the next workout with **Train today**. An interrupted workout instead shows **Resume**. Past unrecorded sessions stay in Programme as missed; they are never marked completed automatically.
2. Tap **Start workout**. Weeks 1–2 use two working sets per exercise and 3 RIR. Warm up with five minutes of easy movement and 3–4 ramp-up sets for the first compound. Record warm-ups separately if useful.
3. For incline dumbbell press, the provisional suggestion is **30 kg per hand**. Tap **Set 1**, enter the weight actually used, whole reps and clean reps left (RIR), then **Complete & save set**. Suggested reps/RIR are never saved as actuals. The rest timer starts immediately. Use **Done** to dismiss the keyboard; the save control sits above it.
4. Tap a saved set to correct it or undo completion. Confirm **Clean form** once for the exercise, or **Needs work**, and flag pain when applicable. Choose your smallest equipment step in **Equipment step & future targets**—for example 2 kg per dumbbell. This updates future recommendations; the current prescription stays frozen.
5. Move to the next exercise. Unknown loads say **Choose a comfortable starting weight**. For unilateral work use reps per side, conservatively the weaker side. Do not double dumbbell loads.
6. Finish upper sessions with the four-direction hand-resisted neck routine. Record actual holds/seconds, moderate effort, neutral head. Stop for the listed symptoms.
7. Tap **Finish workout**. Choose **Complete workout** only when all prescribed sets/holds are logged, or **Save as partial**. The summary shows actual work and recommendations. Closing the screen earlier preserves saved work for **Resume**.

## Features and rules

- Train, Programme, Progress, Settings; native forms, number/decimal pads (comma and dot accepted), Dynamic Type, system light/dark colours, SF Symbols and no app-authored motion.
- Exact chest/back and quad/hamstring split; 47 initial dated slots through 31 December, recurring thereafter. Move/skip retain immutable slot IDs. Recovery checkpoints offer, never force, Light mode.
- Double progression needs all prescribed same-load working sets, top reps, adequate RIR, confirmed clean form, no pain, and a completed normal workout. Mixed loads require a manual next target. Incomplete/partial/skipped/Light sessions never replace the last normal baseline.
- A two-to-three-set transition holds the prior load and establishes the extra set. Rep gains are progress. A stall review requires three comparable completed normal exposures at similar RIR, without rep/load improvement; it never adds sets automatically.
- History separates session templates, equipment setup and load convention. Programme edits apply only to future snapshots. Corrections to past actuals affect recommendations without rewriting prescribed targets. Equipment steps can change independently.
- Morning weight and weekly waist records, actual weekly weight averages with reading counts and adjacent-week changes only. No fabricated body-fat calculation, strength score or guaranteed goal outcome.

## Data and architecture

`Sources/LiftLogCore` contains pure value models, programme, calendar, progression, logging operations and backup validation. `LiftLog` contains SwiftUI, an observable application store, and versioned SwiftData schemas. See [architecture decisions](docs/Architecture.md).

Every meaningful valid edit goes through copy → validate → explicit SwiftData save → publish. Save failures retain the previous saved state and show an error. Completed sets and active snapshots do not rely on app termination. Unconfirmed set drafts can be saved without marking them completed. Rest time is an absolute end timestamp; iOS handles optional notifications, not fake background execution.

The full JSON envelope is version 2; v1 migration supplies timezone/preferences. Version 2 encodes timestamps as Foundation seconds since 2001-01-01 UTC to retain their exact stored precision; legacy ISO-8601 timestamps are accepted. Local date strings and timezones remain separate. The SQLite/SwiftData schema has its own explicit V1 → V2 migration.

**Settings → Export full JSON backup** uses native Files; **CSV** exports actual sets/neck holds with explicit units. Restore validates before confirmation, writes a recoverable copy under Documents/Recovery, then atomically replaces the single SwiftData document. It does not merge or duplicate records. Invalid input leaves the data intact. Recovery files can be shared from Settings or Files → On My iPhone → Lift Log. No automatic cross-device sync, encryption guarantee or permanent retention is claimed. Keep a usable JSON copy outside the app, and test restoration on a disposable simulator before relying on it.

## Development and tests

```bash
# Foundation core, on Mac or a Linux host with Swift 5.9+:
./scripts/test-core.sh
# Dependency-free structural checks (requires Python 3):
python3 scripts/check_project.py
# Only needed if adding/removing source files; the project is already generated:
python3 scripts/generate_project.py
```

The generator is checked in for reproducibility; Xcode does not require Python, XcodeGen, CocoaPods or network package resolution. Existing cloud tasks are isolated: use the existing checkout, no extra Git worktree is necessary. Test fixtures exist only in test targets. DEBUG UI tests use a dedicated store and fixed start date; production never seeds demo workouts.
