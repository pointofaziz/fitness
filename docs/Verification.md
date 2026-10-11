# Verification and Mac handoff

Cloud verification date: 11 October 2026. Host: Debian 13 Linux, x86_64. Toolchain: official Swift 6.2.3 Ubuntu 24.04 distribution, downloaded over verified HTTPS from download.swift.org. There is no Xcode, Apple SDK or iOS simulator on this host.

## Actually executed

| Check | Result | What it establishes |
| --- | --- | --- |
| `SWIFT_BIN=…/swift ./scripts/test-core.sh` | **31 XCTest tests passed, 0 failed, 0 skipped** | The real Foundation core compiles and executes on Linux. |
| Swift `-frontend -parse` over all iOS app and native-test sources | Passed | Swift syntax only, **not** SwiftUI/SwiftData type checking, linking or a runnable iOS build. |
| `python3 scripts/check_project.py` | Passed | All source/resource references exist; three targets, shared scheme, valid plist/XML/JSON and opaque 1024×1024 icon. |
| Foundation `PropertyListSerialization` reading `project.pbxproj` | Passed, 75 objects | The generated OpenStep project file parses. Xcode itself has not opened it here. |
| `git diff --check` | Passed | No whitespace errors. |
| `./scripts/test-ios.sh` | Prerequisite failure as expected | Script exits with a clear Xcode-required message; **no native tests ran**. |

The Swift test tool also prints an empty Swift Testing run after XCTest; the relevant result is the **31 executed XCTest cases**, not that separate zero-test message.

Core coverage includes: exact initial calendar/weekdays and continued dates; template counts/sets; intro and neck holds; qualifying 31 → 32 kg incline; low/missing RIR, form, pain, mixed/incomplete/skipped work; manual targets; warm-up exclusion; per-hand increments; light reduction/baseline isolation; two-to-three-set transition; stalls versus rep improvements; completion-time baseline ordering; separate row identities; stable rescheduling, including bringing a far-future slot forward; zero external weight and input limits; full session logging; active-session/JSON round-trips; immutable historical prescriptions; undo/partial behavior; exact subsecond timestamps; v1 and legacy-date migration; invalid/duplicate backup rejection; weekly averages/missing weeks; Warsaw DST/midnight; elapsed rest and correction without restarting rest; and escaped CSV actuals.

## Authored, not executed here

The Xcode **LiftLogTests** target includes the same 31 core tests plus **4 native tests**:

- Explicit SwiftData save, container reopen and active-set/snapshot recovery.
- SwiftData V1 → V2 migration with real model containers and stable IDs.
- Injected save failure: no in-memory publication, then successful retry.
- Validated replacement, readable recovery backup, duplicate-free repeated restore and rejected invalid data.

The **LiftLogUITests** target contains **4 simulator journeys**:

- First launch → log a set → terminate/relaunch → resume actuals.
- Unconfirmed input rejected, then log and undo.
- Complete all 16 introductory Upper A working sets, form confirmations and four neck holds → summary.
- Four destinations and accessibility-size text smoke checks.

These tests may need adjustments when first compiled/run with the Apple SDK. A successful Linux test is not evidence they pass. The DEBUG UI-test mode uses an isolated test store and a fixed programme-start date; it never inserts demo workouts into production.

## Required on the Mac

1. Open `LiftLog.xcodeproj`, select **LiftLog**, install/select an iOS 17+ simulator runtime, and run **⌘R**. Fix any Apple SDK compilation issues before using real workout data.
2. Run **⌘U** on compact and standard iPhones. Or use `IOS_SIMULATOR_ID=<available UUID> ./scripts/test-ios.sh`; it saves an `.xcresult`. Expected authored count: 35 unit tests and 4 UI tests, none intentionally disabled.
3. On both sizes check each screen, smallest and accessibility Dynamic Type, dark/light modes, portrait safe areas, and no horizontal scrolling. In the set sheet, focus weight/reps/RIR and confirm Save and Done remain reachable above the keyboard. Scroll through long exercise names, neck notes and calendar controls.
4. Use VoiceOver and Accessibility Inspector: exercise identity, unit convention, completion state, form buttons, increment/decrement controls, timer and charts must have meaningful spoken labels. Verify contrast and 44–48 pt targets. Turn Reduce Motion on; the app adds no explicit animations but native transitions still need inspection.
5. In airplane mode complete a session, background/terminate the app during another session, relaunch and restart the simulator/device. Confirm the last saved set, actual inputs and original snapshot persist. Check midnight and Warsaw DST using controlled simulator dates if possible; historical local dates must not change.
6. Validate backup on a disposable simulator: export populated JSON to Files, make an additional record, restore the earlier JSON, confirm replacement and no duplicates, then restore the automatic recovery copy. Try malformed JSON, wrong schema and negative values; ensure data remains unchanged. CSV should show only actual completed sets and holds with the right units.
7. Exercise Light mode after a completed normal session, skip/move calendar entries, and correct old actuals. Check that future recommendations change appropriately without changing old prescriptions or duplicating sessions.

## Required on the iPhone

Follow the README signing/Developer Mode steps. Repeat force-quit and phone-restart recovery. Test real decimal/comma keyboards, one-handed interaction and haptics. Deny notification permission and confirm logging/rest still work; later enable permission, background the app and test timer completion, extension and cancellation. Focus/silent mode can suppress alerts; no audible delivery is guaranteed.

Check current Personal Team expiry/reprovisioning requirements in Apple's official documentation. Back up before reinstalling or changing signing identity. No physical-device signing, notifications, installation or indefinite retention has been verified here.

## Deliberate scope limits

No automatic sync, account, food tracker, body-fat estimate, HealthKit, AI or publishing. Recovery copies live inside the app's Files container and are lost with app deletion unless exported elsewhere. If the native store cannot open, startup shows an error and existing recovery-file sharing rather than silently resetting it. Apple documentation links are supplied in README, but live retrieval was blocked by the cloud egress proxy (HTTP CONNECT 403).
