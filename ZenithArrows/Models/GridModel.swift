// GridModel.swift
// ZenithArrows
// Represents the live game grid and all spatial operations.

import Foundation

// MARK: - Cell Content

enum CellContent {
    case empty
    case arrow(Arrow)
    case obstacle         // immovable wall block
    case portal(id: Int, color: ArrowColor) // teleport pair keyed by id
    case ice              // tile modifier: arrows slide faster
    case trap             // tile modifier: reverses arrow direction on entry
}

// MARK: - Obstacle Model (level-static elements)

struct Obstacle: Codable, Identifiable {
    let id: UUID
    let position: GridPosition
    let kind: ObstacleKind

    enum ObstacleKind: String, Codable {
        case wall, portal, ice, trap
    }

    // Portal pairing
    var portalID: Int?
    var portalColor: ArrowColor?
}

// MARK: - GridModel

final class GridModel: ObservableObject {
    let rows: Int
    let cols: Int

    // Primary storage: row-major flat array for O(1) access
    private(set) var cells: [[CellContent]]

    // Fast lookup: arrow id → position (updated on every mutation)
    private(set) var arrowPositions: [UUID: GridPosition] = [:]

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.cells = Array(repeating: Array(repeating: .empty, count: cols), count: rows)
    }

    // MARK: - Placement

    func place(arrow: Arrow) {
        guard isValid(position: arrow.position) else { return }
        cells[arrow.position.row][arrow.position.col] = .arrow(arrow)
        arrowPositions[arrow.id] = arrow.position
    }

    func place(obstacle: Obstacle) {
        guard isValid(position: obstacle.position) else { return }
        switch obstacle.kind {
        case .wall:
            cells[obstacle.position.row][obstacle.position.col] = .obstacle
        case .portal:
            cells[obstacle.position.row][obstacle.position.col] =
                .portal(id: obstacle.portalID ?? 0, color: obstacle.portalColor ?? .white)
        case .ice:
            cells[obstacle.position.row][obstacle.position.col] = .ice
        case .trap:
            cells[obstacle.position.row][obstacle.position.col] = .trap
        }
    }

    // MARK: - Query

    func content(at position: GridPosition) -> CellContent {
        guard isValid(position: position) else { return .obstacle } // treat OOB as wall
        return cells[position.row][position.col]
    }

    func isValid(position: GridPosition) -> Bool {
        position.row >= 0 && position.row < rows &&
        position.col >= 0 && position.col < cols
    }

    func isEmpty(at position: GridPosition) -> Bool {
        guard isValid(position: position) else { return false }
        switch cells[position.row][position.col] {
        case .empty, .ice: return true
        default: return false
        }
    }

    /// Returns the arrow at a position if one exists
    func arrow(at position: GridPosition) -> Arrow? {
        guard isValid(position: position) else { return nil }
        if case .arrow(let a) = cells[position.row][position.col] { return a }
        return nil
    }

    /// All active (non-removed) arrows
    var activeArrows: [Arrow] {
        arrowPositions.keys.compactMap { id in
            guard let pos = arrowPositions[id] else { return nil }
            return arrow(at: pos)
        }
    }

    // MARK: - Mutation

    /// Remove an arrow from the grid (called after slide-out animation completes)
    func remove(arrowID: UUID) {
        guard let pos = arrowPositions[arrowID] else { return }
        cells[pos.row][pos.col] = .empty
        arrowPositions.removeValue(forKey: arrowID)
    }

    // MARK: - Path checking

    /// Returns all positions an arrow would traverse before exiting, or nil if blocked.
    /// Also returns the portal exit position if a portal is encountered.
    func slidePath(for arrow: Arrow) -> SlidePath? {
        let dir = arrow.direction
        var path: [GridPosition] = []
        var current = arrow.position + dir.delta

        while isValid(position: current) {
            let cell = cells[current.row][current.col]
            switch cell {
            case .empty, .ice:
                path.append(current)
                current = current + dir.delta
            case .portal(let pID, _):
                // Find matching portal exit
                if let exitPos = findPortalExit(id: pID, entryPos: current) {
                    path.append(current)
                    return SlidePath(cells: path, exitsBoardAt: nil, portalExit: exitPos)
                } else {
                    return nil // broken portal = blocked
                }
            case .trap:
                // Trap: arrow reverses—treat remaining path as blocked for simplicity
                // (GameLogic handles actual reversal via new arrow state)
                path.append(current)
                return SlidePath(cells: path, exitsBoardAt: nil, portalExit: nil, trapEncountered: true)
            case .arrow, .obstacle:
                return nil // blocked
            }
        }
        // Arrow exits the board
        return SlidePath(cells: path, exitsBoardAt: current, portalExit: nil)
    }

    private func findPortalExit(id: Int, entryPos: GridPosition) -> GridPosition? {
        for row in 0..<rows {
            for col in 0..<cols {
                let pos = GridPosition(row: row, col: col)
                if pos == entryPos { continue }
                if case .portal(let pid, _) = cells[row][col], pid == id {
                    return pos
                }
            }
        }
        return nil
    }

    // MARK: - Deep copy (for undo stack)

    func copy() -> GridModel {
        let g = GridModel(rows: rows, cols: cols)
        g.cells = cells
        g.arrowPositions = arrowPositions
        return g
    }
}

// MARK: - SlidePath

struct SlidePath {
    let cells: [GridPosition]           // intermediate cells traversed
    let exitsBoardAt: GridPosition?     // first OOB cell (where arrow disappears)
    let portalExit: GridPosition?       // re-entry after portal
    var trapEncountered: Bool = false
}
