// LevelGenerator.swift
// ZenithArrows
// Procedural level generator that guarantees solvability via reverse simulation.
// Algorithm:
//   1. Start with empty grid.
//   2. Repeatedly pick a random empty edge-adjacent direction and place an arrow
//      that could legally slide out from that position (reverse simulation).
//   3. The placement order is the reverse solution order — always solvable.

import Foundation

final class LevelGenerator {

    private let hintEngine = HintEngine()

    // MARK: - Public

    /// Generates a guaranteed-solvable LevelDefinition.
    /// - Parameters:
    ///   - seed: Deterministic seed (use daily date integer for daily challenges).
    ///   - rows, cols: Grid dimensions.
    ///   - arrowCount: Number of arrows to place.
    func generate(
        seed: Int,
        rows: Int,
        cols: Int,
        arrowCount: Int,
        difficulty: LevelDifficulty = .easy,
        worldID: Int = 0
    ) -> LevelDefinition {
        var rng = SeededRNG(seed: seed)
        let placements = buildPlacements(rows: rows, cols: cols,
                                         count: arrowCount, rng: &rng)
        let parMoves = placements.count
        let parTime: TimeInterval = Double(parMoves) * 4.0

        // Build a pseudo LevelDefinition from raw data
        let levelData = """
        {
          "id": "gen_\(seed)",
          "worldID": \(worldID),
          "index": 0,
          "gridRows": \(rows),
          "gridCols": \(cols),
          "arrows": \(arrowPlacementsJSON(placements)),
          "obstacles": [],
          "difficulty": "\(difficulty.rawValue)",
          "parMoves": \(parMoves),
          "parTime": \(parTime),
          "diagonalsEnabled": false,
          "title": "Daily \(seed)"
        }
        """

        let decoder = JSONDecoder()
        // swiftlint:disable:next force_try
        return try! decoder.decode(LevelDefinition.self,
                                   from: Data(levelData.utf8))
    }

    // MARK: - Core Algorithm (Reverse Simulation)

    private func buildPlacements(
        rows: Int,
        cols: Int,
        count: Int,
        rng: inout SeededRNG
    ) -> [ArrowPlacement] {

        let grid = GridModel(rows: rows, cols: cols)
        var placements: [ArrowPlacement] = []
        var attempts = 0
        let maxAttempts = count * 200

        while placements.count < count && attempts < maxAttempts {
            attempts += 1

            // Pick a random empty interior cell
            let row = rng.next(in: 0..<rows)
            let col = rng.next(in: 0..<cols)
            let pos = GridPosition(row: row, col: col)

            guard case .empty = grid.content(at: pos) else { continue }

            // Pick a random direction whose path is currently clear
            let dirs = ArrowDirection.cardinalDirections.shuffled(using: &rng)
            guard let dir = dirs.first(where: { pathIsClear(from: pos, dir: $0, in: grid) })
            else { continue }

            let arrow = Arrow(direction: dir, position: pos)
            grid.place(arrow: arrow)
            placements.append(ArrowPlacement(row: row, col: col, direction: dir))
        }

        return placements
    }

    /// True if every cell from `pos` in `dir` until the board edge is empty.
    private func pathIsClear(from pos: GridPosition, dir: ArrowDirection, in grid: GridModel) -> Bool {
        var current = pos + dir.delta
        while grid.isValid(position: current) {
            if !grid.isEmpty(at: current) { return false }
            current = current + dir.delta
        }
        return true
    }

    // MARK: - JSON Helpers

    private func arrowPlacementsJSON(_ placements: [ArrowPlacement]) -> String {
        let items = placements.map {
            """
            {"row": \($0.row), "col": \($0.col), "direction": "\($0.direction.rawValue)"}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }
}

// MARK: - Seeded RNG (deterministic, not security-sensitive)

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9e3779b97f4a7c15
        _ = next()
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func next(in range: Range<Int>) -> Int {
        let n = range.count
        guard n > 1 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(n))
    }
}

extension Array {
    mutating func shuffled(using rng: inout SeededRNG) -> [Element] {
        var arr = self
        for i in stride(from: arr.count - 1, through: 1, by: -1) {
            let j = rng.next(in: 0..<(i + 1))
            arr.swapAt(i, j)
        }
        return arr
    }
}

extension SeededRNG: Sendable {}
