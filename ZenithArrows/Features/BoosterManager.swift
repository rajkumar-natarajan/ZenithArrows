// BoosterManager.swift
// ZenithArrows
//
// Manages puzzle booster tools giving players targeted assistance beyond hints.
// Competitors (Arrow Out, Arrow Maze) offer: Zoom, Erase, Magic Wand, Grid Lines.
// We match and exceed with: Erase, Auto-Step, Grid Overlay, Skip Level.
//
// ## Boosters
//
// | Booster      | Effect                                    | Cost      |
// |--------------|-------------------------------------------|-----------|
// | erase        | Remove one tapped arrow without penalty   | 3 coins   |
// | autoStep     | Auto-execute the next optimal move        | 5 coins   |
// | skipLevel    | Skip current level, still earns 1 star   | 10 coins  |
//
// ## Coins
//
// Earned at: 1 coin per level complete, 3 coins for 3-star, bonus from ads/IAP.
// Stored in UserDefaults under `zenith_booster_coins_v1`.

import Foundation
import Combine

// MARK: - Booster Types

enum BoosterType: String, Codable, CaseIterable {
    case erase      // Remove 1 arrow without wrong-tap penalty
    case autoStep   // Play the next optimal hint move automatically
    case skipLevel  // Skip the current level (earns 1 star)

    var coinCost: Int {
        switch self {
        case .erase:     return 3
        case .autoStep:  return 5
        case .skipLevel: return 10
        }
    }

    var displayName: String {
        switch self {
        case .erase:     return "Erase"
        case .autoStep:  return "Auto Move"
        case .skipLevel: return "Skip"
        }
    }

    var systemImage: String {
        switch self {
        case .erase:     return "eraser.fill"
        case .autoStep:  return "wand.and.stars"
        case .skipLevel: return "forward.end.fill"
        }
    }
}

// MARK: - BoosterManager

@MainActor
final class BoosterManager: ObservableObject {

    static let shared = BoosterManager()

    @Published private(set) var coins: Int = 0
    @Published var pendingBooster: BoosterType? = nil  // awaiting user tap

    private let storageKey = "zenith_booster_coins_v1"
    private init() { coins = UserDefaults.standard.integer(forKey: storageKey) }

    // MARK: - Coin management

    func addCoins(_ amount: Int) {
        coins += amount
        save()
    }

    func canAfford(_ booster: BoosterType) -> Bool {
        coins >= booster.coinCost
    }

    /// For testing only — directly resets in-memory coins and pending booster to 0/nil.
    func testOnly_reset() {
        coins = 0
        pendingBooster = nil
        UserDefaults.standard.set(0, forKey: storageKey)
    }

    /// Activates a booster if player can afford it.
    /// Returns true if activated; caller should respond to `pendingBooster`.
    @discardableResult
    func activate(_ booster: BoosterType) -> Bool {
        guard canAfford(booster) else { return false }
        coins -= booster.coinCost
        save()
        pendingBooster = booster
        return true
    }

    func cancelPending() {
        pendingBooster = nil
    }

    // MARK: - Rewards

    /// Award coins after a level completion.
    func rewardForLevel(stars: Int) {
        let reward: Int
        switch stars {
        case 3: reward = 3
        case 2: reward = 2
        default: reward = 1
        }
        addCoins(reward)
    }

    /// Award a daily coin bonus (10 coins per day).
    func claimDailyBonus() {
        let key = "zenith_daily_coin_date"
        let today = Calendar.current.startOfDay(for: Date())
        let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
        guard Calendar.current.startOfDay(for: last) < today else { return }
        addCoins(10)
        UserDefaults.standard.set(today, forKey: key)
    }

    private func save() {
        UserDefaults.standard.set(coins, forKey: storageKey)
    }
}
