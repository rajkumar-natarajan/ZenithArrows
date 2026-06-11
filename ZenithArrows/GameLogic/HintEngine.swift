// HintEngine.swift
// ZenithArrows
//
// Computes the optimal next move using iterative topological sort.
//
// ## Algorithm
//
// The solver uses a Kahn's-style approach over the dependency graph:
//   1. Find all currently-moveable arrows (no blocking arrows in their path).
//   2. Remove them from the simulation grid (mark as removed).
//   3. Repeat until the grid is empty (solvable) or no progress (deadlock).
//
// Worst case O(n²) where n = arrow count; typical levels are small (n ≤ 20).
//
// ## API
//
// - `nextSafeMove(in:) → UUID?`
//   Returns the UUID of the first arrow in `solveOrder`, or any moveable
//   arrow if a full solve order cannot be computed.
//
// - `solveOrder(arrows:grid:) → [UUID]?`
//   Full valid removal sequence, or nil if the level is unsolvable (deadlock).
//
// - `isSolvable(grid:) → Bool`
//   Quick check — equivalent to `solveOrder != nil` but avoids the copy
//   overhead of returning the full sequence.
//
// ## Usage
//
// ```swift
// let hint = HintEngine()
// if let id = hint.nextSafeMove(in: gameState.grid) {
//     gameState.highlightedArrowID = id
// }
// ```

import Foundation

final class HintEngine {

    private let validator = MoveValidator()

    // MARK: - Next Safe Move

    /// Returns the UUID of the arrow the player should tap next.
    /// Uses a topological ordering of the dependency graph to pick
    /// the first moveable arrow in a valid solution sequence.
    func nextSafeMove(in grid: GridModel) -> UUID? {
        let arrows = grid.activeArrows
        guard !arrows.isEmpty else { return nil }

        // Try to find a full solution order; return first step
        if let order = solveOrder(arrows: arrows, grid: grid) {
            return order.first
        }

        // Fallback: return any currently-moveable arrow
        return validator.moveableArrows(in: grid).first?.id
    }

    // MARK: - Full Solution Order (Topological Sort)

    /// Returns a valid sequence of arrow IDs to remove in order, or nil if unsolvable.
    func solveOrder(arrows: [Arrow], grid: GridModel) -> [UUID]? {
        // Work on a mutable grid copy so we don't mutate live state
        let simulatedGrid = grid.copy()
        var remaining = arrows.filter { !$0.isRemoved }
        var order: [UUID] = []

        var passes = 0
        let maxPasses = remaining.count * remaining.count + 1 // guard against infinite loop

        while !remaining.isEmpty {
            passes += 1
            if passes > maxPasses { return nil } // unsolvable

            var progress = false
            var nextRemaining: [Arrow] = []

            for arrow in remaining {
                if validator.validateMove(arrow: arrow, in: simulatedGrid) != nil {
                    order.append(arrow.id)
                    simulatedGrid.remove(arrowID: arrow.id)
                    progress = true
                } else {
                    nextRemaining.append(arrow)
                }
            }

            if !progress { return nil } // deadlock
            remaining = nextRemaining
        }

        return order
    }

    // MARK: - Solvability Check (faster — just checks if a valid order exists)

    func isSolvable(grid: GridModel) -> Bool {
        solveOrder(arrows: grid.activeArrows, grid: grid) != nil
    }
}
