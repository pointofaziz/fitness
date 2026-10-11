# Master prompt: build my native iPhone workout app

Act as a senior product engineer and interaction designer experienced in consumer fitness apps. Exercise that judgment through working software, clear tradeoffs and verified behavior. Do not pretend to have personal credentials. Build the app described below, rather than stopping at a plan or producing a visual mockup.

Working name: **Lift Log**. This is initially a personal app for one experienced natural lifter. Its purpose is to make my agreed training programme easy to follow, record and progressively improve on a phone.

## Delivery approach

Work through the five stages at the end of this brief in order. Keep one coherent implementation and continue through the stages without requiring me to send another prompt. Maintain a short plan and meaningful progress updates. Inspect the existing workspace and instructions first. Preserve existing work. Choose sensible defaults where requirements are clear; ask only about decisions that materially block progress.

Build a genuine native iOS app in Swift and SwiftUI, not a website, PWA or webview wrapper. I have a Mac and an iPhone. Work in a dedicated local project folder on my Mac with Xcode available. Inspect macOS, Xcode, installed SDKs, simulators and the project before selecting a supported deployment target. Use current official Apple documentation. Deliver an Xcode project that opens, builds and runs, with unit tests and UI tests. Do not substitute a Swift package alone for the runnable iPhone app.

If Xcode is missing or unsupported on my Mac, identify the exact setup required and continue feasible work without claiming an iOS build passed. Do not change my machine's selected Xcode globally without explaining the need; prefer a scoped DEVELOPER_DIR where appropriate. Do not put signing credentials in source. Keep the project in Git and make reviewable commits. Do not publish to the App Store or TestFlight unless I explicitly request that later. Initial delivery is a simulator-tested app with clear installation steps for my own iPhone.

## My context and constraints

- Age 26; height 186 cm; current weight 81–83 kg; waist 81–82 cm.
- Natural lifter with 4–5 years of training, currently rebuilding consistency. No reported injuries.
- Fully equipped gym. Four sessions weekly: Monday Upper A, Tuesday Lower A, Thursday Upper B, Saturday Lower B.
- Programme starts 12 October 2026. Initial calendar ends 31 December 2026, giving 47 planned sessions. This is only the first part of my six-month goal; the app must remain usable after December.
- Long-term ambition: 90 kg at 10–12% body fat. Show this only as a user goal, never a guaranteed six-month outcome or a calculated body-fat estimate.
- Nutrition reference: 3,200 kcal and approximately 200 g protein daily. Food tracking is outside the initial scope.
- Reported working strength: incline dumbbell press 30–32 kg per hand for 8–10 reps; lat pulldown 80 kg for 10–12; squat 100–120 kg for 8–10; conventional deadlift 120–130 kg for 8–10. These are self-reported working sets, not tested maxima.

## The experience to build

Design primarily for one-handed use on a phone while resting between sets. The main loop is:

Open app → see next workout → start or resume → log each set → rest → finish → see what to aim for next time.

Use four navigation destinations: **Train, Programme, Progress, Settings**. Keep primary controls within comfortable thumb reach. During an active workout, keep the current exercise, previous performance, targets and rest timer accessible without navigating between screens.

Train should show the next scheduled session, its focus, approximate duration and one dominant Start button. If a workout is in progress, Resume takes priority. Rest days should show the next session with an option to train today. Allow moving or skipping a workout without duplicating it or silently deleting history. Do not label an unrecorded past session completed.

Workout interaction:
- Show the exercise name, set count, rep range, target reps in reserve, load convention and brief technique cue.
- Show previous actual results and the current recommendation separately. Label an initial weight as provisional; never present it as previously lifted in the app.
- Each set has weight, reps, RIR and a completion control. RIR means clean reps left; explain it briefly on demand.
- Prefill weight from the recommendation. Leave actual reps/RIR unconfirmed until the user records them; suggested values must never become actual results automatically.
- Use a decimal keypad for kg and integer input for reps. Provide small increment/decrement controls. Avoid forcing a custom keyboard if the native keypad works better.
- On set completion, save immediately and start the rest timer. Provide undo and editing of completed sets.
- Ask once per exercise whether the recorded sets used clean form. Keep this one-tap. Missing form confirmation should not qualify a load increase.
- A short explanation such as “All 3 sets reached 10 reps with 2 reps left: try 32 kg next time” should make progression understandable.
- Warm-up sets can be recorded separately and never count toward working-set progression.
- Allow an exercise to be skipped with an optional reason. An unfinished workout can be saved as partial. Never fabricate missing sets.
- Workout summary shows actual work completed and recommendations. Avoid gamification that rewards heavier weight despite worsening form.

Use a restrained, readable visual style: charcoal background, high-contrast text, one accent colour, clear spacing and a system font. Support light mode and reduced motion. No decorative stock fitness imagery, fake charts, excessive gradients or motivational popups. Use at least 44–48 pt tap targets, visible focus, meaningful labels and status text that does not rely on colour alone. Check compact and standard iPhone sizes, keyboard overlap and device safe areas. Keep screens legible rather than shrinking tables onto a phone.

## Exact programme

Keep these exercise choices and the chest/back and quad/hamstring emphasis. Sets below are the full programme, excluding warm-ups.

### Upper A — chest focus
1. Incline dumbbell press — 3 × 6–10
2. Flat machine chest press — 3 × 8–12
3. Chest-supported row — 3 × 8–12
4. Cable chest fly — 2 × 12–15
5. Lat pulldown — 2 × 8–12
6. Cable lateral raise — 3 × 12–20
7. Overhead cable triceps extension — 3 × 10–15
8. Preacher curl — 3 × 10–15
9. Neck routine below

### Lower A — quads
1. Barbell back squat — 3 × 6–8
2. Leg press — 3 × 10–15
3. Leg extension — 2 × 12–15
4. Seated leg curl — 2 × 10–15
5. Hip adductor machine, thighs together — 2 × 12–20
6. Standing calf raise — 3 × 8–12
7. Cable crunch — 3 × 10–15

### Upper B — back focus
1. Neutral-grip lat pulldown — 3 × 8–12
2. Chest-supported row — 3 × 8–12
3. Flat dumbbell press — 3 × 8–12
4. One-arm cable row — 2 × 10–15 per side
5. Seated dumbbell shoulder press — 2 × 8–12
6. Cable lateral raise — 3 × 12–20
7. Reverse pec deck — 3 × 12–20
8. Cable triceps pushdown — 3 × 10–15
9. Dumbbell curl — 3 × 10–15
10. Neck routine below

### Lower B — hamstrings and glutes
1. Romanian deadlift — 3 × 6–10
2. Seated leg curl — 3 × 10–15
3. Hip thrust — 2 × 8–12
4. Reverse lunge — 2 × 8–12 per leg
5. Hip adductor machine — 2 × 12–20
6. Seated calf raise — 3 × 12–20
7. Hanging knee raise or captain’s-chair knee raise — 3 × 10–15

### Neck
After both upper sessions: hand-resisted isometric holds forward, backward, left and right with the head neutral. Weeks 1–2: one 10–15-second hold per direction. Then two holds per direction, building comfortable holds toward 20 seconds before modestly increasing manual resistance. Moderate effort. Record seconds, holds and optional comfort notes, not kg or RIR progression. Stop for pain, headache, dizziness, tingling or arm symptoms. No neck bridges or automatic load increases.

### Introductory and lighter sessions
First two programme weeks: two working sets per weighted exercise and 3 RIR. From week 3: prescribed sets. Default compounds to 2 RIR; isolation work can use 1–2, with an explicit editable target stored with the session. Squats/RDL remain at 2 RIR.

Offer recovery checkpoints after 6–8 weeks, without automatically diagnosing fatigue or forcing a lighter week. User-selected Light mode roughly halves sets, rounding up, uses about 10% less load rounded to available equipment, and targets 4 RIR. Preserve the normal load separately. A light session does not earn a load increase or permanently lower the normal target.

Rest defaults: squat/RDL 180 seconds, other compounds 150 seconds, isolation/abs 90 seconds; editable. General warm-up: five minutes of easy movement and 3–4 ramp-up sets for the first compound, plus additional warm-ups as needed.

## Progression engine

Implement a deterministic, separately testable function returning an action, next load, next rep target and plain-language reason. No AI service is required for this.

Use double progression. Increasing load is earned at each exposure to the same exercise in the same session template, not on a fixed weekly percentage schedule.

An increase qualifies only when:
1. All prescribed working sets were completed, with valid weight/reps/RIR entries.
2. All sets reached at least the top of the rep range.
3. Every set met or exceeded the minimum target RIR.
4. Clean form was confirmed, with no pain flag.
5. The session was not Light, skipped or partial for that exercise.
6. The working sets used the same load. If loads differ, show “Review mixed loads” and require a manual next target; do not guess which weight earned an increase.

When eligible, add the configured equipment increment. Otherwise hold the load and suggest one extra total clean rep when appropriate. Never force an increase when below the minimum reps, effort was excessive or technique worsened. Do not turn one poor session into a prescribed deload.

Initial suggestions: incline DB press 30 kg per hand, standard lat pulldown 75 kg, back squat 100 kg. These are provisional and must be editable. All other loaded exercises begin with “Choose a comfortable starting weight.” Conventional deadlift strength must not seed RDL strength. Knee raises begin at bodyweight with zero external kg; zero is valid data, not a missing value.

Default increments: squat/RDL 2.5 kg total; other equipment smallest available increment. Offer editable values, including 1 or 2 kg per dumbbell, and 2.5 or 5 kg on machines. Explain that 30 to 32 kg is a 6.7% increase; increments are equipment choices, not guaranteed weekly gains. Ask for the equipment step only when relevant, not in a long onboarding form.

Track Monday and Thursday rows separately even when the exercise name matches. Preserve stable exercise and session identifiers. Machine weights are comparable only with the same machine and setup. Store load units explicitly: per hand, total barbell, per side, machine scale, bodyweight. For unilateral exercises log reps per side or conservatively use the weaker side; clearly identify which convention applies. Do not double per-hand weight in recommendations.

Show stalled-progress review only after three comparable completed normal exposures without rep/load improvement at similar RIR. Missing sessions and improvements in reps at the same load do not count as stalls. Changes in set count, equipment or rep range break comparability. Do not automatically add sets.

Freeze the prescription snapshot when a workout starts. Later edits to the programme must not rewrite past sessions. Corrections to old actuals can update future recommendations but must not change historical prescribed targets. Use actual completed timestamps when resolving rescheduled workouts. Incomplete or skipped sessions must not replace the last valid baseline.

## Progress and body tracking

Provide an exercise history showing actual weight, reps and RIR, with a session-template selector. Simple charts should reveal trends without inventing muscle gain from training volume. Avoid combining kg from different machines into a misleading strength score.

Allow morning body-weight entries and weekly waist entries. Calculate weekly averages from recorded weights; missing days are not zero. Display the number of readings. Show a weekly change only when both weeks contain data. The reference gain range is roughly 0.15–0.25 kg/week; show it as an initial planning range. Do not estimate body fat from waist or claim 90 kg is guaranteed.

## Native iOS architecture and reliability

Use SwiftUI, native navigation and forms, SF Symbols and system typography. Use Swift Charts for simple progress charts if supported by the selected deployment target. Follow Apple Human Interface Guidelines. Support Dynamic Type, VoiceOver, reduced motion, light/dark mode, safe areas and native decimal/number pads with an accessible Done control. Keep primary workout controls reachable when the keyboard is visible. Parse both comma and dot decimal input correctly for my locale.

Prefer a modest architecture separating SwiftUI views, application state, persistence and a pure Swift progression engine. Use SwiftData with explicit saves and a versioned schema if the selected iOS target supports it; otherwise choose a supported persistence approach and document why. Avoid third-party dependencies unless necessary. Do not add accounts, servers, subscription payments, HealthKit or AI calls to the initial version.

V1 stores records on the device and works fully offline from first launch. Explain in Settings that it has no automatic cross-device sync and that deleting the app or losing the device can lose records unless a usable backup exists. Do not claim cloud backup, encryption or permanent retention without implementation and verification.

Save meaningful edits explicitly and transactionally, especially completed sets. Do not rely on deferred autosave or the app's termination callback. Preserve an active workout across backgrounding, force quit, relaunch and phone restart. Show failed saves and recovery actions. Keep a consistent normal-load baseline separate from light-session performance.

Provide full versioned JSON export and validated restore using native Files/share interfaces, plus CSV training-log export. Test schema migrations and stable IDs. Make a recoverable backup before replacing existing records. Invalid imports must leave existing data intact; restoration must not duplicate records. Confirm destructive resets and imports that replace data. Demo data belongs only in previews/tests.

Store timestamps separately from local calendar dates. Use Europe/Warsaw initially and handle DST, timezone changes and midnight explicitly. Compute rest time from an end timestamp and refresh it when the app becomes active. Optional local notifications can announce the timer after permission is granted; cancel or update them when the timer changes. Handle permission denied and Focus/silent settings without guaranteeing audible alerts. Use native haptics for in-app actions where enabled. Do not fake continuous background execution or misuse background audio.

Provide an app icon asset and a unique configurable bundle identifier. Build/test on supported iPhone simulators. Document physical-device setup: select the user's Apple account/team in Xcode, automatic signing, connect/trust the iPhone, enable Developer Mode when required, select the device and Run. Never request Apple account passwords in chat.

Explain current free Personal Team signing limitations with official Apple documentation. Initial personal testing can use a free account, but do not promise an indefinitely installed app. Paid developer membership and TestFlight/App Store delivery are later options, not prerequisites for simulator development. Do not pretend a simulator run verifies physical-device signing, notifications or installation.

## Build in five stages

1. **Foundation:** inspect repo, choose architecture, document essential decisions, model the data and seed the exact programme. Set up migrations and progression logic. Use stable IDs from the start.
2. **Gym workflow:** implement Train, programme view, start/resume, set entry, RIR/form input, rest timer, autosave, edit/undo and finish/partial completion. Test one entire session before adding more screens.
3. **Progression and history:** connect recommendations, exercise history, body tracking, programme editing and lighter-session handling. Explain every recommendation in ordinary language.
4. **Phone reliability:** implement native persistence, lifecycle recovery, schema migrations, local timer notifications, JSON export/restore and CSV export. Refine keyboard behavior, reachability and accessibility. Check layouts on phone-sized screens.
5. **Verification and delivery:** run relevant unit tests and simulator UI journeys, fix failures and build the runnable Xcode project. Provide the project location, simulator evidence, iPhone installation steps, a concise usage guide and any verified limitations.

Do not stop after a planning document. Keep the stages small enough to validate incrementally. If the environment requires checkpoints, show concrete working progress at each one.

## Required acceptance checks

- First-use user opens the app and reaches the correct next workout without a lengthy account/setup flow.
- A completed set survives force quit and relaunch. An active workout resumes with its original target snapshot.
- Incline press at 30 kg, three sets of 10, RIR 2 each and clean form qualifies for 32 kg when the step is 2 kg.
- The same reps with RIR 0, missing RIR, poor form, pain, mixed loads or an incomplete set do not qualify.
- Adding a rep at the same load is recognized as progress, not a stall.
- Intro two-set work does not falsely establish three-set performance. The transition adds the third set without assuming it was previously achieved.
- A light session uses reduced volume/load and does not replace the normal baseline or earn an increase.
- A missed or rescheduled session neither duplicates workouts nor loses the prior valid baseline.
- Bodyweight zero external load is valid. Invalid negatives, nonnumeric input and unreasonable entries receive clear validation rather than recommendations.
- Editing past results does not rewrite the original prescribed targets.
- JSON export/restore round-trips real records accurately; invalid imports leave existing records intact.
- First launch and completed workouts work in airplane mode. Relaunch preserves active sets; a simulated schema migration preserves records.
- All 47 initial calendar entries match the agreed weekdays and date range. Training remains usable after the initial calendar.
- Mobile views on compact and standard iPhone simulators have no horizontal scrolling or keyboard-obscured primary input.
- VoiceOver labels, Dynamic Type, keyboard dismissal, contrast and reduced motion are checked. Local notification permission denial does not block training.

Deliver the runnable Xcode project, working native app, readable source and a short README with setup, architecture, progression rules, data/backup behavior, test commands and personal-device installation instructions. Distinguish tests actually run from physical-device checks still needed. Finish by explaining how I log my first workout.
