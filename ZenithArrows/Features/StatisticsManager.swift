// StatisticsManager.swift
// ZenithArrows
//
// Tracks per-level and per-world statistics for the profile screen.
// Competitors show: best moves per level, completion %, total time played.
// We add: average solve time, total combos, booster usage frequency.
//
// Stored as JSON in UserDefaults under `zenith_statistics_v1`.

import Foundation
import Combine

// MARK: - Level Stats Entry

struct LevelStat: Codable, Identifiable {
    var id: String { levelID }
    let levelID: String
    var attempts: Int = 0
    var completions: Int = 0
    var bestMoves: Int = Int.max
    var bestTime: TimeInterval = .infinity
    var totalTime: TimeInterval = 0
    var hintsUsed: Int = 0
    var boostersUsed: Int = 0
    var maxCombo: Int = 0

    var completionRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(completions) / Double(attempts)
    }

    var averageTime: TimeInterval {
        guard completions > 0 else { return 0 }
        return totalTime / Double(completions)
    }
}

// MARK: - Global Stats

struct GlobalStats: Codable {
    var totalPlayTime: TimeInterval = 0
    var totalLevelsAttempted: Int = 0
    var totalLevelsCompleted: Int = 0
    var totalMovesAllTime: Int = 0
    var totalCombosAllTime: Int = 0
    var totalBoostersUsed: Int = 0
    var longestSession: TimeInterval = 0
    var currentSessionStart: Date? = nil
}

// MARK: - StatisticsManager

@MainActor
final class StatisticsManager: ObservableObject {

    static let shared = StatisticsManager()

    @Published private(set) var levelStats: [String: LevelStat] = [:]
    @Published private(set) var global: GlobalStats = GlobalStats()

    private let storageKey = "zenith_statistics_v1"
    private let globalKey  = "zenith_global_stats_v1"
    private var sessionStartTime: Date = Date()

    private init() {
        load()
        sessionStartTime = Date()
        global.currentSessionStart = sessionStartTime
    }

    // MARK: - Recording

    func recordLevelStarted(levelID: String) {
        var stat = levelStats[levelID] ?? LevelStat(levelID: levelID)
        stat.attempts += 1
        levelStats[levelID] = stat
        global.totalLevelsAttempted += 1
        save()
    }

    func recordLevelCompleted(
        levelID: String,
        moves: Int,
        time: TimeInterval,
        hintsUsed: Int,
        boostersUsed: Int,
        maxCombo: Int
    ) {
        var stat = levelStats[levelID] ?? LevelStat(levelID: levelID)
        stat.completions += 1
        if moves < stat.bestMoves { stat.bestMoves = moves }
        if time < stat.bestTime { stat.bestTime = time }
        stat.totalTime += time
        stat.hintsUsed += hintsUsed
        stat.boostersUsed += boostersUsed
        if maxCombo > stat.maxCombo { stat.maxCombo = maxCombo }
        levelStats[levelID] = stat

        global.totalLevelsCompleted += 1
        global.totalMovesAllTime += moves
        global.totalPlayTime += time
        global.totalCombosAllTime += maxCombo
        global.totalBoostersUsed += boostersUsed
        save()
    }

    func recordBoosterUsed() {
        global.totalBoostersUsed += 1
        save()
    }

    // MARK: - Queries

    func stat(for levelID: String) -> LevelStat? {
        levelStats[levelID]
    }

    var overallCompletionRate: Double {
        guard global.totalLevelsAttempted > 0 else { return 0 }
        return Double(global.totalLevelsCompleted) / Double(global.totalLevelsAttempted)
    }

    func worldCompletionRate(world: World) -> Double {
        let total = world.levels.count
        guard total > 0 else { return 0 }
        let completed = world.levels.filter { ($0.bestStars) > 0 }.count
        return Double(completed) / Double(total)
    }

    var totalPlayTimeFormatted: String {
        let total = Int(global.totalPlayTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(levelStats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(global) {
            UserDefaults.standard.set(data, forKey: globalKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stats = try? JSONDecoder().decode([String: LevelStat].self, from: data) {
            levelStats = stats
        }
        if let data = UserDefaults.standard.data(forKey: globalKey),
           let g = try? JSONDecoder().decode(GlobalStats.self, from: data) {
            global = g
        }
    }
}
