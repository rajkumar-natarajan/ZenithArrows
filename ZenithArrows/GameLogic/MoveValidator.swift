// MoveValidator.swift
// ZenithArrows
// Pure logic — determines whether a given arrow can be slid out right now.

import Foundation

final class MoveValidator {

    /// Returns a SlidePath if the arrow can legally move, otherwise nil.
    func validateMove(arrow: Arrow, in grid: GridModel) -> SlidePath? {
        guard !arrow.isRemoved else { return nil }
        guard arrow.type != .locked else { return nil }

        // Heavy arrows need their row/col fully clear of all other arrows first
        if arrow.type == .heavy && !isHeavyArrowUnlocked(arrow: arrow, in: grid) {
            return nil
        }

        return grid.slidePath(for: arrow)
    }

    /// Returns the set of arrows that are currently moveable (no obstacles in their path)
    func moveableArrows(in grid: GridModel) -> [Arrow] {
        grid.activeArrows.filter { validateMove(arrow: $0, in: grid) != nil }
    }

    // MARK: - Heavy Arrow Rule

    /// A heavy arrow can only move if no other arrow occupies its row (horizontal)
    /// or column (vertical) ahead of it, depending on its direction.
    private func isHeavyArrowUnlocked(arrow: Arrow, in grid: GridModel) -> Bool {
        let dir = arrow.direction
        switch dir {
        case .left, .right:
            // All cells in the same row must be empty (except this arrow)
            for col in 0..<grid.cols {
                let pos = GridPosition(row: arrow.position.row, col: col)
                if pos == arrow.position { continue }
                if grid.arrow(at: pos) != nil { return false }
            }
        case .up, .down:
            for row in 0..<grid.rows {
                let pos = GridPosition(row: row, col: arrow.position.col)
                if pos == arrow.position { continue }
                if grid.arrow(at: pos) != nil { return false }
            }
        default:
            break
        }
        return true
    }

    // MARK: - Dependency Graph

    /// Builds a map: arrowID → set of arrowIDs that must be removed first
    /// before the key arrow can move. Used by HintEngine and SolvabilityChecker.
    func buildDependencyGraph(for arrows: [Arrow], in grid: GridModel) -> [UUID: Set<UUID>] {
        var graph: [UUID: Set<UUID>] = [:]

        for arrow in arrows {
            guard !arrow.isRemoved else { continue }
            var blockers: Set<UUID> = []
            var pos = arrow.position + arrow.direction.delta

            while grid.isValid(position: pos) {
                if let blocker = grid.arrow(at: pos) {
                    blockers.insert(blocker.id)
                }
                pos = pos + arrow.direction.delta
            }
            graph[arrow.id] = blockers
        }
        return graph
    }
}
