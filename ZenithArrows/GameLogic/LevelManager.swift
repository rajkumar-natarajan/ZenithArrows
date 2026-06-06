// LevelManager.swift
// ZenithArrows
// Loads, manages, and persists all level and world data.

import Foundation
import Combine

@MainActor
final class LevelManager: ObservableObject {

    static let shared = LevelManager()

    @Published private(set) var worlds: [World] = []
    @Published private(set) var dailyChallenge: LevelDefinition? = nil

    private let progressKey = "zenith_progress_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadAllWorlds()
        loadProgress()
        generateDailyChallenge()
    }

    // MARK: - Data Loading

    private func loadAllWorlds() {
        let worldFiles = ["world1", "world2", "world3", "world4"]
        worlds = worldFiles.compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let world = try? decoder.decode(World.self, from: data) else {
                return nil
            }
            return world
        }

        // Unlock world 1 by default
        if !worlds.isEmpty {
            worlds[0].isUnlocked = true
            if !worlds[0].levels.isEmpty {
                worlds[0].levels[0].isUnlocked = true
            }
        }
    }

    // MARK: - Progress Persistence

    private struct ProgressRecord: Codable {
        var levelStars: [String: Int]      // levelID → best stars
        var unlockedLevelIDs: [String]
        var unlockedWorldIDs: [Int]
        var totalStars: Int
    }

    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let record = try? decoder.decode(ProgressRecord.self, from: data) else { return }

        for wi in worlds.indices {
            if record.unlockedWorldIDs.contains(worlds[wi].id) {
                worlds[wi].isUnlocked = true
            }
            for li in worlds[wi].levels.indices {
                let lid = worlds[wi].levels[li].id
                if record.unlockedLevelIDs.contains(lid) {
                    worlds[wi].levels[li].isUnlocked = true
                }
                if let stars = record.levelStars[lid] {
                    worlds[wi].levels[li].bestStars = stars
                }
            }
        }
    }

    func saveProgress(levelID: String, stars: Int) {
        var record: ProgressRecord = loadRawProgress() ?? ProgressRecord(
            levelStars: [:], unlockedLevelIDs: [], unlockedWorldIDs: [1], totalStars: 0
        )

        let previous = record.levelStars[levelID] ?? 0
        if stars > previous {
            record.totalStars += (stars - previous)
            record.levelStars[levelID] = stars
        }

        // Unlock next level
        if let (wi, li) = findLevel(id: levelID) {
            let nextLI = li + 1
            if nextLI < worlds[wi].levels.count {
                let nextID = worlds[wi].levels[nextLI].id
                if !record.unlockedLevelIDs.contains(nextID) {
                    record.unlockedLevelIDs.append(nextID)
                }
                worlds[wi].levels[nextLI].isUnlocked = true
            } else {
                // Unlock next world
                let nextWI = wi + 1
                if nextWI < worlds.count &&
                   record.totalStars >= worlds[nextWI].requiredStarsToUnlock {
                    let nextWID = worlds[nextWI].id
                    if !record.unlockedWorldIDs.contains(nextWID) {
                        record.unlockedWorldIDs.append(nextWID)
                    }
                    worlds[nextWI].isUnlocked = true
                    if !worlds[nextWI].levels.isEmpty {
                        worlds[nextWI].levels[0].isUnlocked = true
                    }
                }
            }
        }

        if let data = try? encoder.encode(record) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
        loadProgress() // re-sync @Published
    }

    private func loadRawProgress() -> ProgressRecord? {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else { return nil }
        return try? decoder.decode(ProgressRecord.self, from: data)
    }

    // MARK: - Lookup

    func findLevel(id: String) -> (worldIndex: Int, levelIndex: Int)? {
        for (wi, world) in worlds.enumerated() {
            for (li, level) in world.levels.enumerated() {
                if level.id == id { return (wi, li) }
            }
        }
        return nil
    }

    func level(id: String) -> LevelDefinition? {
        guard let (wi, li) = findLevel(id: id) else { return nil }
        return worlds[wi].levels[li]
    }

    var totalStars: Int {
        worlds.flatMap(\.levels).map(\.bestStars).reduce(0, +)
    }

    // MARK: - Daily Challenge

    private func generateDailyChallenge() {
        // Generate a deterministic daily level based on the date seed
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let seed = Int(today.timeIntervalSince1970 / 86400)
        let generator = LevelGenerator()
        dailyChallenge = generator.generate(seed: seed, rows: 5, cols: 5, arrowCount: 12)
    }
}
