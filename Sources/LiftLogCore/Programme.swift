import Foundation

public enum Programme {
    static func e(_ id: String, _ name: String, _ sets: Int, _ low: Int, _ high: Int, _ unit: LoadUnit = .machine, _ compound: Bool = false, _ cue: String, initial: Double? = nil, step: Double? = nil, unilateral: Bool = false, longRest: Bool = false) -> Exercise {
        Exercise(id: id, name: name, sets: sets, minReps: low, maxReps: high, targetRIR: compound ? 2 : 1, restSeconds: longRest ? 180 : (compound ? 150 : 90), unit: unit, cue: cue, unilateral: unilateral, initialLoad: initial, increment: step, equipment: "Default setup")
    }
    public static let templates: [SessionTemplate] = [
        SessionTemplate(id: "upper-a", name: "Upper A", focus: "Chest focus", weekday: 2, minutes: 80, exercises: [
            e("ua-incline", "Incline dumbbell press", 3, 6, 10, .perHand, true, "Keep shoulder blades supported; control the lowering.", initial: 30),
            e("ua-press", "Flat machine chest press", 3, 8, 12, .machine, true, "Keep wrists stacked and shoulders comfortable."),
            e("ua-row", "Chest-supported row", 3, 8, 12, .machine, true, "Keep chest on pad; avoid jerking."),
            e("ua-fly", "Cable chest fly", 2, 12, 15, .perSide, false, "Keep a soft elbow bend and use a comfortable stretch."),
            e("ua-pulldown", "Lat pulldown", 2, 8, 12, .machine, true, "Pull elbows down without swinging.", initial: 75),
            e("ua-lateral", "Cable lateral raise", 3, 12, 20, .perSide, false, "Lead with elbows; keep shoulders relaxed.", unilateral: true),
            e("ua-triceps", "Overhead cable triceps extension", 3, 10, 15, .machine, false, "Keep upper arms steady."),
            e("ua-curl", "Preacher curl", 3, 10, 15, .machine, false, "Control the bottom; avoid bouncing.")
        ], neck: true),
        SessionTemplate(id: "lower-a", name: "Lower A", focus: "Quads", weekday: 3, minutes: 65, exercises: [
            e("la-squat", "Barbell back squat", 3, 6, 8, .total, true, "Brace and use a repeatable comfortable depth.", initial: 100, step: 2.5, longRest: true),
            e("la-press", "Leg press", 3, 10, 15, .machine, true, "Keep pelvis supported; control depth."),
            e("la-extension", "Leg extension", 2, 12, 15, .machine, false, "Use controlled reps without kicking."),
            e("la-curl", "Seated leg curl", 2, 10, 15, .machine, false, "Keep hips on the seat."),
            e("la-adductor", "Hip adductor machine, thighs together", 2, 12, 20, .machine, false, "Bring thighs together with control."),
            e("la-calf", "Standing calf raise", 3, 8, 12, .machine, false, "Pause in a comfortable stretch; avoid bouncing."),
            e("la-crunch", "Cable crunch", 3, 10, 15, .machine, false, "Curl the trunk without pulling with the arms.")
        ], neck: false),
        SessionTemplate(id: "upper-b", name: "Upper B", focus: "Back focus", weekday: 5, minutes: 85, exercises: [
            e("ub-pulldown", "Neutral-grip lat pulldown", 3, 8, 12, .machine, true, "Drive elbows down; keep the trunk steady."),
            e("ub-row", "Chest-supported row", 3, 8, 12, .machine, true, "Keep chest supported and pause briefly."),
            e("ub-press", "Flat dumbbell press", 3, 8, 12, .perHand, true, "Control the lowering and keep wrists stacked."),
            e("ub-one-row", "One-arm cable row", 2, 10, 15, .machine, true, "Log reps per side using the weaker side; avoid rotation.", unilateral: true),
            e("ub-shoulder", "Seated dumbbell shoulder press", 2, 8, 12, .perHand, true, "Keep ribs down and use a comfortable range."),
            e("ub-lateral", "Cable lateral raise", 3, 12, 20, .perSide, false, "Raise with control; avoid shrugging.", unilateral: true),
            e("ub-reverse", "Reverse pec deck", 3, 12, 20, .machine, false, "Move through the shoulders without arching."),
            e("ub-triceps", "Cable triceps pushdown", 3, 10, 15, .machine, false, "Keep elbows near the body."),
            e("ub-curl", "Dumbbell curl", 3, 10, 15, .perHand, false, "Keep upper arms still; avoid swinging.")
        ], neck: true),
        SessionTemplate(id: "lower-b", name: "Lower B", focus: "Hamstrings and glutes", weekday: 7, minutes: 70, exercises: [
            e("lb-rdl", "Romanian deadlift", 3, 6, 10, .total, true, "Hinge at the hips; stop before losing a neutral back.", step: 2.5, longRest: true),
            e("lb-curl", "Seated leg curl", 3, 10, 15, .machine, false, "Keep hips down and control the return."),
            e("lb-thrust", "Hip thrust", 2, 8, 12, .total, true, "Finish with the glutes without overextending the back."),
            e("lb-lunge", "Reverse lunge", 2, 8, 12, .perHand, true, "Log reps per leg using the weaker side; keep balance.", unilateral: true),
            e("lb-adductor", "Hip adductor machine", 2, 12, 20, .machine, false, "Bring thighs together with control."),
            e("lb-calf", "Seated calf raise", 3, 12, 20, .machine, false, "Pause briefly at both ends of a comfortable range."),
            e("lb-knee", "Hanging knee raise or captain’s-chair knee raise", 3, 10, 15, .bodyweight, false, "Curl the pelvis without swinging.", initial: 0)
        ], neck: false)
    ]
    public static let neckSafety = "Head neutral; moderate hand resistance. Stop for pain, headache, dizziness, tingling or arm symptoms. No neck bridges or automatic load increases."
    public static let warmup = "Five minutes of easy movement, then 3–4 ramp-up sets for the first compound. Add warm-ups as needed."
}

public enum Schedule {
    public static func calendar(_ zone: String = "Europe/Warsaw") -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone) ?? TimeZone(secondsFromGMT: 0)!; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c
    }
    public static func day(_ date: Date, zone: String = "Europe/Warsaw") -> String {
        let c = calendar(zone); let d = c.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", d.year!, d.month!, d.day!)
    }
    public static func date(_ day: String, zone: String = "Europe/Warsaw") -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10 else { return nil }
        let c = calendar(zone)
        guard let d = c.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)), self.day(d, zone: zone) == day else { return nil }
        return d
    }
    public static func week(on day: String, zone: String = "Europe/Warsaw") -> Int {
        guard let start = date("2026-10-12", zone: zone), let current = date(day, zone: zone) else { return 1 }
        return max(1, (calendar(zone).dateComponents([.day], from: start, to: current).day ?? 0) / 7 + 1)
    }
    public static func entries(through end: String, data: AppData) -> [ScheduleEntry] {
        let c = calendar(data.timeZoneID)
        guard var cursor = date("2026-10-12", zone: data.timeZoneID), let last = date(end, zone: data.timeZoneID) else { return [] }
        var result: [ScheduleEntry] = []
        while cursor <= last {
            let key = day(cursor, zone: data.timeZoneID)
            if let template = data.templates.first(where: { $0.weekday == c.component(.weekday, from: cursor) }) {
                let id = "\(key)-\(template.id)"
                result.append(data.scheduleChanges.first(where: { $0.id == id }) ?? ScheduleEntry(id: id, templateID: template.id, originalDate: key, date: key))
            }
            cursor = c.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
    public static func next(data: AppData, now: Date) -> ScheduleEntry? {
        let today = day(now, zone: data.timeZoneID)
        let horizon = day(calendar(data.timeZoneID).date(byAdding: .day, value: 90, to: now)!, zone: data.timeZoneID)
        return entries(through: max("2026-12-31", horizon), data: data).first { entry in
            !entry.skipped && entry.date >= today && !data.workouts.contains(where: { w in w.scheduleID == entry.id })
        }
    }
    public static func move(_ entry: ScheduleEntry, to day: String, data: inout AppData) throws {
        guard date(day, zone: data.timeZoneID) != nil, !data.workouts.contains(where: { $0.scheduleID == entry.id }) else { throw LogError.invalid("Only unstarted sessions can be moved.") }
        var moved = entry; moved.date = day
        data.scheduleChanges.removeAll { $0.id == entry.id }; data.scheduleChanges.append(moved)
    }
}
