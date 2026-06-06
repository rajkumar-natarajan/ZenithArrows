// ProgressManager.swift
// ZenithArrows
// Tracks lifetime stats, IAP entitlements, and daily streak.

import Foundation
import Combine
import GameKit

@MainActor
final class ProgressManager: ObservableObject {

    static let shared = ProgressManager()

    // MARK: - Published
    @Published private(set) var totalStars: Int = 0
    @Published private(set) var totalMoves: Int = 0
    @Published private(set) var dailyStreak: Int = 0
    @Published private(set) var hintsOwned: Int = 3
    @Published var hasPremiumUnlock: Bool = false   // IAP: full level pack
    @Published var hasRemovedAds: Bool = false       // IAP: ad removal

    // MARK: - Keys
    private let statsKey = "zenith_stats_v1"

    private struct Stats: Codable {
        var totalStars: Int = 0
        var totalMoves: Int = 0
        var dailyStreak: Int = 0
        var hintsOwned: Int = 3
        var lastPlayedDate: Date?
    }

    private init() { load() }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else { return }
        totalStars   = stats.totalStars
        totalMoves   = stats.totalMoves
        dailyStreak  = stats.dailyStreak
        hintsOwned   = stats.hintsOwned
        updateStreak(lastDate: stats.lastPlayedDate)
    }

    private func save() {
        let stats = Stats(totalStars: totalStars, totalMoves: totalMoves,
                          dailyStreak: dailyStreak, hintsOwned: hintsOwned,
                          lastPlayedDate: Date())
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    // MARK: - Updates

    func recordLevelComplete(stars: Int, moves: Int) {
        totalStars += stars
        totalMoves += moves
        save()
        reportToGameCenter(stars: stars)
    }

    func addHints(_ count: Int) {
        hintsOwned += count
        save()
    }

    func useHint() {
        hintsOwned = max(0, hintsOwned - 1)
        save()
    }

    // MARK: - Daily Streak

    private func updateStreak(lastDate: Date?) {
        guard let last = lastDate else {
            dailyStreak = 1
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: last)
        let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if diff == 1 {
            dailyStreak += 1
        } else if diff > 1 {
            dailyStreak = 1
        }
        // diff == 0 means same day, streak unchanged
    }

    // MARK: - Game Center

    private func reportToGameCenter(stars: Int) {
        let score = GKScore(leaderboardIdentifier: "zenith_total_stars")
        score.value = Int64(totalStars)
        GKScore.report([score]) { _ in /* silent */ }
    }

    func authenticateGameCenter() {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { _, _ in /* handle VC if needed */ }
    }

    func showLeaderboard(from vc: UIViewController) {
        let gcVC = GKGameCenterViewController(leaderboardID: "zenith_total_stars",
                                               playerScope: .global,
                                               timeScope: .allTime)
        gcVC.gameCenterDelegate = vc as? GKGameCenterControllerDelegate
        vc.present(gcVC, animated: true)
    }
}
