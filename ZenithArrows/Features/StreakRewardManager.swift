// StreakRewardManager.swift
// ZenithArrows
//
// Feature 9: Streak Rewards.
//
// Checks the player's `dailyStreak` against milestone thresholds and
// grants rewards (hints or theme unlocks) exactly once per milestone.
//
// ## Milestones
//
// | Streak | Reward                  |
// |--------|-------------------------|
// | 3      | +3 hints                |
// | 7      | +7 hints                |
// | 14     | Neon City theme unlock  |
// | 30     | Cyber theme unlock      |
// | 60     | +25 hints               |
// | 100    | Pure Dark theme unlock  |
//
// ## Reward Application
//
// - `.hints` → `ProgressManager.shared.addHints(_:)`
// - `.themeUnlock` → `ThemeManager.shared.unlockTheme(key:)`
//
// ## One-at-a-Time Display
//
// `pendingReward` is set to the first unclaimed eligible milestone.
// `HomeView` shows `StreakRewardView` while `pendingReward != nil`.
// After dismissal, `dismissPendingReward()` checks for additional
// pending milestones recursively.
//
// ## Persistence
//
// `[StreakMilestone]` JSON stored in `zenith_streak_rewards_v1`.
// Merge strategy: catalog milestones are the source of truth for IDs;
// only the `isClaimed` flag is preserved from saved data.

import Foundation
import Combine

// MARK: - Streak Milestone

struct StreakMilestone: Identifiable, Codable {
    let id: Int                 // streak day count required
    let title: String
    let description: String
    let rewardType: RewardType
    let rewardValue: Int        // quantity (hints, stars, etc.)
    var isClaimed: Bool = false

    enum RewardType: String, Codable {
        case hints
        case themeUnlock        // unlock a theme by key (rewardKey)
        case starBonus
    }

    var rewardKey: String?      // used for themeUnlock
}

// MARK: - StreakRewardManager

@MainActor
final class StreakRewardManager: ObservableObject {

    static let shared = StreakRewardManager()

    @Published private(set) var milestones: [StreakMilestone] = []
    @Published private(set) var pendingReward: StreakMilestone? = nil   // triggers reward popup

    private let storageKey = "zenith_streak_rewards_v1"

    static let allMilestones: [StreakMilestone] = [
        StreakMilestone(id: 3,  title: "3-Day Streak!",  description: "3 days in a row!",
                        rewardType: .hints, rewardValue: 3),
        StreakMilestone(id: 7,  title: "Week Warrior",   description: "7 days straight!",
                        rewardType: .hints, rewardValue: 7),
        StreakMilestone(id: 14, title: "Fortnight Focus", description: "14 days of puzzles!",
                        rewardType: .themeUnlock, rewardValue: 1, rewardKey: "neon"),
        StreakMilestone(id: 30, title: "Monthly Master",  description: "30-day streak legend!",
                        rewardType: .themeUnlock, rewardValue: 1, rewardKey: "cyber"),
        StreakMilestone(id: 60, title: "Unstoppable",     description: "60 days!",
                        rewardType: .hints, rewardValue: 25),
        StreakMilestone(id: 100, title: "Century Solver",  description: "100-day streak!",
                        rewardType: .themeUnlock, rewardValue: 1, rewardKey: "dark")
    ]

    private init() {
        load()
    }

    // MARK: - Check on Login / App Open

    func checkStreakRewards(currentStreak: Int) {
        for i in milestones.indices {
            let m = milestones[i]
            guard !m.isClaimed, currentStreak >= m.id else { continue }
            milestones[i].isClaimed = true
            pendingReward = milestones[i]
            applyReward(milestones[i])
            save()
            break   // show one reward at a time
        }
    }

    func dismissPendingReward() {
        pendingReward = nil
        // Check if more rewards are pending
        checkStreakRewards(currentStreak: ProgressManager.shared.dailyStreak)
    }

    // MARK: - Reward Application

    private func applyReward(_ milestone: StreakMilestone) {
        switch milestone.rewardType {
        case .hints:
            ProgressManager.shared.addHints(milestone.rewardValue)
        case .themeUnlock:
            if let key = milestone.rewardKey {
                ThemeManager.shared.unlockTheme(key: key)
            }
        case .starBonus:
            break   // reserved for future use
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([StreakMilestone].self, from: data) else {
            milestones = StreakRewardManager.allMilestones
            return
        }
        // Merge: keep any new milestones added in updates, preserve claim state
        var claimedIDs = Set(saved.filter(\.isClaimed).map(\.id))
        milestones = StreakRewardManager.allMilestones.map { m in
            var copy = m
            copy.isClaimed = claimedIDs.contains(m.id)
            return copy
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(milestones) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
