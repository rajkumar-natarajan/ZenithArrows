// ComboEngine.swift
// ZenithArrows
//
// Feature 2: Arrow Chain Combos.
//
// Detects cascade reactions: after an arrow is removed from the grid,
// if any other arrow immediately becomes moveable (was previously blocked
// by the removed arrow), a combo is registered.
//
// ## Combo State
//
// `ComboState` tracks:
//   - `streak: Int` — consecutive cascade removals
//   - `multiplier: Double` = 1.0 + streak × 0.5  (1.5× → 2.0× → 2.5× ...)
//   - `totalBonus: Int` — running bonus tally
//
// ## Banner Labels
// | Streak | Label               |
// |--------|---------------------|
// | 2      | "COMBO x2!"         |
// | 3      | "TRIPLE!"           |
// | 4      | "MEGA COMBO x4!"    |
// | 5+     | "UNSTOPPABLE xN!"   |
//
// ## Integration
//
// `evaluate(afterRemovingID:in:)` is called from `GameState.commitMove`
// immediately after `grid.remove(arrowID:)`.  Returns `true` on cascade.
// `GameHUDView` observes `lastComboText` to show/hide the banner.

import Foundation
import Combine

// MARK: - Combo State

struct ComboState {
    var streak: Int = 0         // consecutive cascade removals
    var multiplier: Double = 1.0
    var totalBonus: Int = 0

    mutating func increment() {
        streak += 1
        multiplier = 1.0 + Double(streak) * 0.5  // 1.5×, 2.0×, 2.5× …
        totalBonus += Int(Double(streak) * 10 * multiplier)
    }

    mutating func reset() {
        streak = 0
        multiplier = 1.0
    }
}

// MARK: - ComboEngine

@MainActor
final class ComboEngine: ObservableObject {

    @Published private(set) var currentCombo: ComboState = ComboState()
    @Published private(set) var lastComboText: String? = nil // "COMBO x3!" flash

    private let validator = MoveValidator()
    private var comboResetTask: Task<Void, Never>? = nil

    // MARK: - Cascade Check

    /// Call after each arrow removal. Passes the grid AFTER the arrow has been removed.
    /// Returns true if a cascade was detected (newly-unlocked arrows exist).
    @discardableResult
    func evaluate(afterRemovingID removedID: UUID, in grid: GridModel) -> Bool {
        let moveableNow = validator.moveableArrows(in: grid)
        let isCascade = !moveableNow.isEmpty

        if isCascade {
            currentCombo.increment()
            lastComboText = comboLabel(streak: currentCombo.streak)
            scheduleComboReset()
        } else {
            finaliseCombo()
        }

        return isCascade
    }

    /// Forces an immediate combo reset (e.g., player paused or restarted).
    func reset() {
        comboResetTask?.cancel()
        comboResetTask = nil
        currentCombo.reset()
        lastComboText = nil
    }

    // MARK: - Private

    private func finaliseCombo() {
        comboResetTask?.cancel()
        if currentCombo.streak > 1 {
            // Keep label visible for 1.2 s after chain ends
            scheduleComboReset(delay: 1.2)
        } else {
            currentCombo.reset()
            lastComboText = nil
        }
    }

    private func scheduleComboReset(delay: Double = 2.0) {
        comboResetTask?.cancel()
        comboResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            currentCombo.reset()
            lastComboText = nil
        }
    }

    private func comboLabel(streak: Int) -> String {
        switch streak {
        case 2: return "COMBO x2!"
        case 3: return "TRIPLE!"
        case 4: return "MEGA COMBO x4!"
        default: return streak > 4 ? "UNSTOPPABLE x\(streak)!" : ""
        }
    }
}
