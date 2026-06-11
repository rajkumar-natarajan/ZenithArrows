// SeasonalEventManager.swift
// ZenithArrows
//
// Manages seasonal/themed events with special level packs and cosmetics.
// Inspired by Arrow Maze "Coral Carnival" and competitor event systems.
//
// Events are date-range based, loaded from a local catalog.
// Each event grants: themed level pack, exclusive theme unlock, bonus coins.
//
// Stored in `zenith_seasonal_events_v1`.

import Foundation
import SwiftUI
import Combine

// MARK: - Seasonal Event

struct SeasonalEvent: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconSystemImage: String
    let accentColorHex: String
    let startDate: Date
    let endDate: Date
    var isCompleted: Bool = false
    var coinsEarned: Int = 0
    let rewardThemeKey: String?     // exclusive theme unlock on completion
    let rewardCoins: Int
    let levelIDs: [String]          // IDs of special event levels

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }
}

// MARK: - SeasonalEventManager

@MainActor
final class SeasonalEventManager: ObservableObject {

    static let shared = SeasonalEventManager()

    @Published private(set) var events: [SeasonalEvent] = []
    @Published private(set) var activeEvent: SeasonalEvent? = nil

    private let storageKey = "zenith_seasonal_events_v1"

    // Hard-coded event calendar — expandable via remote config later
    static let catalog: [SeasonalEvent] = [
        SeasonalEvent(
            id: "summer2026",
            name: "Summer Blaze",
            description: "Beat 5 fire-themed puzzles to unlock the Neon City theme!",
            iconSystemImage: "sun.max.fill",
            accentColorHex: "FF6B35",
            startDate: date(2026, 6, 1),
            endDate: date(2026, 8, 31),
            rewardThemeKey: "neon",
            rewardCoins: 25,
            levelIDs: ["event_summer_1","event_summer_2","event_summer_3","event_summer_4","event_summer_5"]
        ),
        SeasonalEvent(
            id: "halloween2026",
            name: "Haunted Grid",
            description: "Navigate spooky arrow mazes. Complete all to unlock Pure Dark theme!",
            iconSystemImage: "moon.stars.fill",
            accentColorHex: "9B59B6",
            startDate: date(2026, 10, 15),
            endDate: date(2026, 11, 1),
            rewardThemeKey: "dark",
            rewardCoins: 30,
            levelIDs: ["event_halloween_1","event_halloween_2","event_halloween_3","event_halloween_4","event_halloween_5"]
        ),
        SeasonalEvent(
            id: "winter2026",
            name: "Frozen Arrows",
            description: "Ice tile special levels. Unlock Nature theme on completion!",
            iconSystemImage: "snowflake",
            accentColorHex: "AED6F1",
            startDate: date(2026, 12, 1),
            endDate: date(2026, 12, 31),
            rewardThemeKey: "nature",
            rewardCoins: 30,
            levelIDs: ["event_winter_1","event_winter_2","event_winter_3","event_winter_4","event_winter_5"]
        )
    ]

    private init() {
        load()
        refreshActive()
    }

    // MARK: - Active Event

    private func refreshActive() {
        activeEvent = events.first(where: { $0.isActive && !$0.isCompleted })
    }

    func completeEvent(id: String) {
        guard let idx = events.firstIndex(where: { $0.id == id }) else { return }
        events[idx].isCompleted = true
        // Grant reward
        BoosterManager.shared.addCoins(events[idx].rewardCoins)
        if let themeKey = events[idx].rewardThemeKey {
            ThemeManager.shared.unlockTheme(key: themeKey)
        }
        activeEvent = nil
        save()
    }

    // MARK: - Event Level Generation

    func eventLevel(id: String) -> LevelDefinition? {
        // Generate deterministic event levels from ID hash
        let seed = abs(id.hashValue) % 9999
        let generator = LevelGenerator()
        return generator.generate(
            seed: seed,
            rows: 5, cols: 5,
            arrowCount: 10,
            difficulty: .hard,
            worldID: 99
        )
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SeasonalEvent].self, from: data) {
            // Merge catalog with saved completion state
            let savedMap = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            events = SeasonalEventManager.catalog.map { e in
                var copy = e
                copy.isCompleted = savedMap[e.id]?.isCompleted ?? false
                return copy
            }
        } else {
            events = SeasonalEventManager.catalog
        }
        refreshActive()
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return Calendar.current.date(from: comps) ?? Date()
    }
}
