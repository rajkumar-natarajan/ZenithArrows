// WeeklyChallengeManager.swift
// ZenithArrows
//
// Feature 6: Weekly Challenges.
//
// Generates a fresh hard puzzle every Monday using a deterministic seed
// derived from the ISO-8601 week identifier (e.g. "2026-W24").
//
// ## Lifecycle
//
// 1. On init, `refreshIfNeeded()` compares the stored week ID to the current
//    ISO week.  If different, the old challenge is archived and a new one
//    generated.
// 2. A 60-second timer updates `timeUntilReset` and re-checks each minute.
//
// ## Challenge Generation
//
// Seed = `weekID.hashValue & 0x7FFFFFFF` (positive)
// Level: 6×6 grid, 12 arrows, `.hard` difficulty.
// Falls back to a hand-coded 5-arrow layout if the generator fails.
//
// ## Persistence
//
// Stored in `zenith_weekly_v1` as `Storage{current, past}` (JSON).
// Up to 8 past challenges are retained for reference in the History section.
//
// ## Completion Recording
//
// `recordCompletion(stars:score:)` only improves stored values (best-of
// semantics — a worse replay cannot overwrite a better result).

import Foundation
import Combine

// MARK: - Weekly Challenge Entry

struct WeeklyChallenge: Codable, Identifiable {
    var id: String { weekID }
    let weekID: String           // "2026-W23"
    let levelDefinition: LevelDefinition
    let expiresAt: Date
    var bestStars: Int = 0
    var bestScore: Int = 0
    var completed: Bool = false
}

// MARK: - WeeklyChallengeManager

@MainActor
final class WeeklyChallengeManager: ObservableObject {

    static let shared = WeeklyChallengeManager()

    @Published private(set) var current: WeeklyChallenge? = nil
    @Published private(set) var past: [WeeklyChallenge] = []
    @Published private(set) var timeUntilReset: TimeInterval = 0

    private var resetTimer: AnyCancellable?
    private let storageKey = "zenith_weekly_v1"
    private let generator = LevelGenerator()

    private init() {
        load()
        refreshIfNeeded()
        startResetTimer()
    }

    // MARK: - Refresh Logic

    private func refreshIfNeeded() {
        let weekID = currentWeekID()
        if current?.weekID != weekID {
            if let old = current {
                past.insert(old, at: 0)
                if past.count > 8 { past.removeLast() }
            }
            current = generateWeeklyChallenge(weekID: weekID)
            save()
        }
    }

    private func generateWeeklyChallenge(weekID: String) -> WeeklyChallenge {
        let seed = weekID.hashValue & 0x7FFFFFFF  // positive seed
        let level = generator.generate(
            seed: seed,
            rows: 6, cols: 6,
            arrowCount: 12,
            difficulty: .hard,
            worldID: 99
        ) ?? fallbackLevel(weekID: weekID)

        let expires = nextMonday()
        return WeeklyChallenge(
            weekID: weekID,
            levelDefinition: level,
            expiresAt: expires
        )
    }

    private func fallbackLevel(weekID: String) -> LevelDefinition {
        LevelDefinition(
            id: "weekly_\(weekID)",
            worldID: 99, index: 1,
            gridRows: 5, gridCols: 5,
            arrows: [
                ArrowPlacement(row: 0, col: 0, direction: .right),
                ArrowPlacement(row: 0, col: 4, direction: .down),
                ArrowPlacement(row: 4, col: 4, direction: .left),
                ArrowPlacement(row: 4, col: 0, direction: .up),
                ArrowPlacement(row: 2, col: 2, direction: .right)
            ],
            difficulty: .hard,
            parMoves: 5,
            title: "Weekly \(weekID)"
        )
    }

    // MARK: - Completion

    func recordCompletion(stars: Int, score: Int) {
        guard var challenge = current else { return }
        if stars > challenge.bestStars || score > challenge.bestScore {
            challenge.bestStars = max(challenge.bestStars, stars)
            challenge.bestScore = max(challenge.bestScore, score)
            challenge.completed = true
            current = challenge
            save()
        }
    }

    // MARK: - Time Remaining

    var timeRemainingFormatted: String {
        let t = Int(timeUntilReset)
        let days = t / 86400
        let hours = (t % 86400) / 3600
        let mins = (t % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    // MARK: - Persistence

    private struct Storage: Codable {
        var current: WeeklyChallenge?
        var past: [WeeklyChallenge]
    }

    private func save() {
        let storage = Storage(current: current, past: past)
        if let data = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let storage = try? JSONDecoder().decode(Storage.self, from: data) else { return }
        current = storage.current
        past = storage.past
    }

    // MARK: - Helpers

    private func currentWeekID() -> String {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let year = comps.yearForWeekOfYear ?? 2026
        let week = comps.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }

    private func nextMonday() -> Date {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: Date())
        let daysUntilMonday = (9 - cal.component(.weekday, from: today)) % 7
        return cal.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: today)!
    }

    private func startResetTimer() {
        timeUntilReset = nextMonday().timeIntervalSinceNow
        resetTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.timeUntilReset = self.nextMonday().timeIntervalSinceNow
                self.refreshIfNeeded()
            }
    }
}
