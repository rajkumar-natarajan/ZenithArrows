// AchievementManager.swift
// ZenithArrows
//
// Feature 10: Star-Based Achievements.
//
// Manages a catalog of 14 in-app achievements that mirror GameCenter
// achievement IDs and are surfaced in the in-app `AchievementsView`.
//
// ## Achievement Requirements
//
// | Requirement Type         | Description                              |
// |--------------------------|------------------------------------------|
// | `.totalStars(n)`         | Earn n cumulative stars                  |
// | `.totalMoves(n)`         | Make n cumulative taps                   |
// | `.dailyStreak(n)`        | Maintain n-day streak                    |
// | `.perfectLevel`          | 3-star any single level                  |
// | `.perfectWorld(id)`      | 3-star every level in a world            |
// | `.timedModeCompletion(n)`| Complete n timed challenges              |
// | `.comboStreak(n)`        | Reach x-n combo in a single level        |
// | `.noHintWorldClear(id)`  | Clear a world without using any hints    |
//
// ## Progress & Unlock
//
// `update(stars:moves:streak:comboMax:timedCompletions:levelStars:worlds:)`
// iterates the catalog, evaluates each requirement, updates `progress` (0–1)
// and sets `isUnlocked` when `progress == 1.0`.  Reports to GameCenter via
// `GKAchievement.report`.
//
// ## Persistence
//
// `[Achievement]` JSON in `zenith_achievements_v2`.
// Merge strategy: catalog is the source of truth for new achievements;
// `progress` and `isUnlocked` are loaded from persisted data.

import Foundation
import GameKit

// MARK: - Achievement Definition

struct Achievement: Identifiable, Codable {
    let id: String                  // matches GameCenter achievement ID
    let title: String
    let description: String
    let systemImage: String
    let requirement: AchievementRequirement
    var progress: Double = 0.0      // 0.0 – 1.0
    var isUnlocked: Bool = false
    var unlockedAt: Date? = nil

    enum AchievementRequirement: Codable {
        case totalStars(Int)
        case totalMoves(Int)
        case dailyStreak(Int)
        case noHintWorldClear(Int)   // world ID
        case timedModeCompletion(Int) // count of timed completions
        case comboStreak(Int)         // max combo in a single level
        case perfectLevel             // 3-star any level
        case perfectWorld(Int)        // 3-star all levels in world
    }
}

// MARK: - AchievementManager

@MainActor
final class AchievementManager: ObservableObject {

    static let shared = AchievementManager()

    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var newlyUnlocked: Achievement? = nil  // triggers popup

    private let storageKey = "zenith_achievements_v2"

    static let catalog: [Achievement] = [
        Achievement(id: "zenith.stars.10",     title: "Star Collector",      description: "Earn 10 stars",      systemImage: "star.fill",              requirement: .totalStars(10)),
        Achievement(id: "zenith.stars.50",     title: "Star Hunter",         description: "Earn 50 stars",      systemImage: "star.circle.fill",        requirement: .totalStars(50)),
        Achievement(id: "zenith.stars.100",    title: "Star Hoarder",        description: "Earn 100 stars",     systemImage: "sparkles",                requirement: .totalStars(100)),
        Achievement(id: "zenith.stars.500",    title: "Star Legend",         description: "Earn 500 stars",     systemImage: "trophy.fill",             requirement: .totalStars(500)),
        Achievement(id: "zenith.perfect.first",title: "Flawless",            description: "3-star any level",   systemImage: "checkmark.seal.fill",    requirement: .perfectLevel),
        Achievement(id: "zenith.perfect.w1",   title: "World 1 Master",      description: "3-star all World 1 levels", systemImage: "1.circle.fill",   requirement: .perfectWorld(1)),
        Achievement(id: "zenith.streak.7",     title: "Week Warrior",        description: "7-day streak",       systemImage: "flame.fill",              requirement: .dailyStreak(7)),
        Achievement(id: "zenith.streak.30",    title: "Monthly Master",      description: "30-day streak",      systemImage: "calendar.badge.checkmark", requirement: .dailyStreak(30)),
        Achievement(id: "zenith.moves.1000",   title: "Nimble Fingers",      description: "Make 1,000 moves",   systemImage: "hand.tap.fill",           requirement: .totalMoves(1000)),
        Achievement(id: "zenith.moves.10000",  title: "Arrow Veteran",       description: "Make 10,000 moves",  systemImage: "arrow.triangle.2.circlepath", requirement: .totalMoves(10000)),
        Achievement(id: "zenith.timed.5",      title: "Speed Demon",         description: "Complete 5 timed challenges", systemImage: "timer",         requirement: .timedModeCompletion(5)),
        Achievement(id: "zenith.combo.3",      title: "Chain Reaction",      description: "Achieve a x3 combo", systemImage: "bolt.fill",              requirement: .comboStreak(3)),
        Achievement(id: "zenith.combo.5",      title: "Avalanche",           description: "Achieve a x5 combo", systemImage: "bolt.circle.fill",       requirement: .comboStreak(5)),
        Achievement(id: "zenith.nohint.w1",    title: "No Peeking",          description: "Clear World 1 without hints", systemImage: "eye.slash.fill", requirement: .noHintWorldClear(1))
    ]

    private init() {
        load()
    }

    // MARK: - Progress Update

    func update(stars: Int, moves: Int, streak: Int, comboMax: Int,
                timedCompletions: Int, levelStars: [String: Int], worlds: [World]) {
        var changed = false

        for i in achievements.indices {
            guard !achievements[i].isUnlocked else { continue }
            let (newProgress, unlocked) = evaluate(
                achievement: achievements[i],
                stars: stars, moves: moves, streak: streak,
                comboMax: comboMax, timedCompletions: timedCompletions,
                levelStars: levelStars, worlds: worlds
            )
            if newProgress != achievements[i].progress {
                achievements[i].progress = newProgress
                changed = true
            }
            if unlocked && !achievements[i].isUnlocked {
                achievements[i].isUnlocked = true
                achievements[i].unlockedAt = Date()
                achievements[i].progress = 1.0
                newlyUnlocked = achievements[i]
                reportToGameCenter(achievements[i])
                changed = true
            }
        }

        if changed { save() }
    }

    func dismissNewUnlock() {
        newlyUnlocked = nil
    }

    var unlockedCount: Int { achievements.filter(\.isUnlocked).count }
    var totalCount: Int { achievements.count }

    // MARK: - Evaluation

    private func evaluate(
        achievement: Achievement,
        stars: Int, moves: Int, streak: Int,
        comboMax: Int, timedCompletions: Int,
        levelStars: [String: Int], worlds: [World]
    ) -> (progress: Double, unlocked: Bool) {

        switch achievement.requirement {
        case .totalStars(let target):
            let p = min(1.0, Double(stars) / Double(target))
            return (p, stars >= target)

        case .totalMoves(let target):
            let p = min(1.0, Double(moves) / Double(target))
            return (p, moves >= target)

        case .dailyStreak(let target):
            let p = min(1.0, Double(streak) / Double(target))
            return (p, streak >= target)

        case .perfectLevel:
            let hasPerfect = levelStars.values.contains(3)
            return (hasPerfect ? 1.0 : 0.0, hasPerfect)

        case .perfectWorld(let worldID):
            guard let world = worlds.first(where: { $0.id == worldID }) else { return (0, false) }
            let total = world.levels.count
            guard total > 0 else { return (0, false) }
            let perfect = world.levels.filter { $0.bestStars == 3 }.count
            let p = Double(perfect) / Double(total)
            return (p, perfect == total)

        case .timedModeCompletion(let target):
            let p = min(1.0, Double(timedCompletions) / Double(target))
            return (p, timedCompletions >= target)

        case .comboStreak(let target):
            let p = min(1.0, Double(comboMax) / Double(target))
            return (p, comboMax >= target)

        case .noHintWorldClear(let worldID):
            // Tracked separately via ProgressManager flag
            let flag = UserDefaults.standard.bool(forKey: "zenith_nohint_world_\(worldID)")
            return (flag ? 1.0 : 0.0, flag)
        }
    }

    // MARK: - GameCenter

    private func reportToGameCenter(_ achievement: Achievement) {
        let gcAchievement = GKAchievement(identifier: achievement.id)
        gcAchievement.percentComplete = 100
        gcAchievement.showsCompletionBanner = true
        GKAchievement.report([gcAchievement]) { _ in /* silent */ }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Achievement].self, from: data) else {
            achievements = AchievementManager.catalog
            return
        }
        // Merge catalog with saved progress
        let savedMap = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        achievements = AchievementManager.catalog.map { a in
            guard let s = savedMap[a.id] else { return a }
            var copy = a
            copy.progress = s.progress
            copy.isUnlocked = s.isUnlocked
            copy.unlockedAt = s.unlockedAt
            return copy
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
