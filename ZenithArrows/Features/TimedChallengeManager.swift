// TimedChallengeManager.swift
// ZenithArrows
//
// Feature 1: Timed Challenge Mode.
//
// Provides a countdown-based scoring mode separate from the standard
// relaxed puzzle flow.  Two configurations are supplied:
//   - `standard`: 60-second countdown, +10 per under-par move, -25 per mistake.
//   - `blitz`:    30-second countdown, +20 per under-par move, -50 per mistake.
//
// ## Score Formula
// ```
// finalScore = max(0, baseScore ± moveAdjustments) + (timeRemaining × 2)
// ```
//
// ## Star Thresholds
// - 3 stars: ≥20 s remaining
// - 2 stars: ≥10 s remaining
// - 1 star:  completed with <10 s remaining
// - 0 stars: time expired (`isExpired == true`)
//
// ## Persistence
//
// Best scores stored per `levelID` in `zenith_timed_best_scores_v1`
// (JSON-encoded `[String: Int]`); new scores only saved if they beat the
// current best.

import Foundation
import Combine

// MARK: - Timed Challenge Configuration

struct TimedChallengeConfig {
    let totalSeconds: Int       // countdown duration
    let bonusPerMove: Int       // points for each move under par
    let penaltyPerMistake: Int  // points deducted per mistake
    let baseScore: Int          // score for completion regardless of time

    static let standard = TimedChallengeConfig(
        totalSeconds: 60,
        bonusPerMove: 10,
        penaltyPerMistake: 25,
        baseScore: 100
    )

    static let blitz = TimedChallengeConfig(
        totalSeconds: 30,
        bonusPerMove: 20,
        penaltyPerMistake: 50,
        baseScore: 150
    )
}

// MARK: - Timed Challenge Result

struct TimedChallengeResult {
    let completed: Bool
    let timeRemaining: Int
    let moves: Int
    let mistakes: Int
    let finalScore: Int
    let stars: Int              // 1–3 based on time remaining
}

// MARK: - TimedChallengeManager

@MainActor
final class TimedChallengeManager: ObservableObject {

    static let shared = TimedChallengeManager()

    @Published private(set) var isActive: Bool = false
    @Published private(set) var timeRemaining: Int = 0
    @Published private(set) var currentScore: Int = 0
    @Published private(set) var isExpired: Bool = false
    @Published private(set) var config: TimedChallengeConfig = .standard

    private var countdownTimer: AnyCancellable?
    private let bestScoreKey = "zenith_timed_best_scores_v1"

    private init() {}

    // MARK: - Session Control

    func start(config: TimedChallengeConfig = .standard) {
        self.config = config
        timeRemaining = config.totalSeconds
        currentScore = config.baseScore
        isExpired = false
        isActive = true
        startCountdown()
    }

    func stop() {
        countdownTimer?.cancel()
        countdownTimer = nil
        isActive = false
    }

    func pause() {
        countdownTimer?.cancel()
        countdownTimer = nil
    }

    func resume() {
        guard isActive, !isExpired else { return }
        startCountdown()
    }

    // MARK: - Score Updates

    func recordMove(underPar: Bool) {
        guard isActive else { return }
        if underPar {
            currentScore += config.bonusPerMove
        }
    }

    func recordMistake() {
        guard isActive else { return }
        currentScore = max(0, currentScore - config.penaltyPerMistake)
    }

    // Time bonus — remaining seconds each worth 2 points
    func computeResult(moves: Int, mistakes: Int) -> TimedChallengeResult {
        let timeBonus = timeRemaining * 2
        let finalScore = max(0, currentScore + timeBonus)
        let stars: Int
        switch timeRemaining {
        case 20...: stars = 3
        case 10..<20: stars = 2
        default: stars = isExpired ? 0 : 1
        }
        return TimedChallengeResult(
            completed: !isExpired,
            timeRemaining: timeRemaining,
            moves: moves,
            mistakes: mistakes,
            finalScore: finalScore,
            stars: stars
        )
    }

    // MARK: - Best Score Persistence

    func saveBestScore(_ score: Int, forLevelID id: String) {
        var scores = loadBestScores()
        let existing = scores[id] ?? 0
        if score > existing {
            scores[id] = score
            if let data = try? JSONEncoder().encode(scores) {
                UserDefaults.standard.set(data, forKey: bestScoreKey)
            }
        }
    }

    func bestScore(forLevelID id: String) -> Int {
        loadBestScores()[id] ?? 0
    }

    private func loadBestScores() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: bestScoreKey),
              let scores = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return scores
    }

    // MARK: - Private

    private func startCountdown() {
        countdownTimer?.cancel()
        countdownTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.isExpired = true
                    self.stop()
                }
            }
    }
}
