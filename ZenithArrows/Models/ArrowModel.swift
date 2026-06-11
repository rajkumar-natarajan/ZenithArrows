// ArrowModel.swift
// ZenithArrows
//
// Core data model representing a single arrow on the game grid.
//
// ## Key Types
//
// - `ArrowDirection`: 8 cardinal + diagonal directions with movement deltas,
//   rotation degrees for rendering, and SF Symbol names.
// - `ArrowType`: standard | ice | heavy | locked | rotatable (Feature 3) |
//   snake (Feature 4).
// - `ArrowColor`: 7 colours used for portal pairing (white → no portal).
// - `GridPosition`: Hashable (row, col) coordinate struct with `+` operator.
// - `Arrow`: `ObservableObject` entity with full `Codable` support for
//   undo-stack serialisation.
//
// ## Feature Extensions
//
// - Rotatable arrows (Feature 3): `rotateClockwise/CounterClockwise(diagonalsEnabled:)`
//   cycles through cardinal or all-8 directions; no-ops on non-rotatable types.
// - Snake arrows (Feature 4): `addSegment(_:)`, `head`, `tail`, `isSnake`
//   properties for multi-cell arrow management.

import Foundation
import SwiftUI

// MARK: - Arrow Direction

enum ArrowDirection: String, Codable, CaseIterable {
    case up    = "up"
    case down  = "down"
    case left  = "left"
    case right = "right"
    // Advanced diagonal directions (unlocked in later worlds)
    case upLeft    = "upLeft"
    case upRight   = "upRight"
    case downLeft  = "downLeft"
    case downRight = "downRight"

    /// Unit vector for each direction
    var delta: (row: Int, col: Int) {
        switch self {
        case .up:        return (-1,  0)
        case .down:      return ( 1,  0)
        case .left:      return ( 0, -1)
        case .right:     return ( 0,  1)
        case .upLeft:    return (-1, -1)
        case .upRight:   return (-1,  1)
        case .downLeft:  return ( 1, -1)
        case .downRight: return ( 1,  1)
        }
    }

    /// SF Symbol name for rendering fallback
    var systemImageName: String {
        switch self {
        case .up:        return "arrow.up"
        case .down:      return "arrow.down"
        case .left:      return "arrow.left"
        case .right:     return "arrow.right"
        case .upLeft:    return "arrow.up.left"
        case .upRight:   return "arrow.up.right"
        case .downLeft:  return "arrow.down.left"
        case .downRight: return "arrow.down.right"
        }
    }

    /// Rotation angle for rendering arrows as a single up-pointing asset
    var rotationDegrees: Double {
        switch self {
        case .up:        return 0
        case .right:     return 90
        case .down:      return 180
        case .left:      return 270
        case .upRight:   return 45
        case .downRight: return 135
        case .downLeft:  return 225
        case .upLeft:    return 315
        }
    }

    /// Cardinal-only directions for basic gameplay
    static var cardinalDirections: [ArrowDirection] { [.up, .down, .left, .right] }
}

// MARK: - Arrow Type

enum ArrowType: String, Codable {
    case standard    // Normal arrow
    case snake       // Multi-segment occupying multiple cells
    case rotatable   // Player can rotate before launching
    case ice         // Slides faster, travels further
    case heavy       // Cannot be moved until other arrows clear its row/col
    case locked      // Immovable obstacle (acts as wall for pathing)
}

// MARK: - Arrow Color (for portal matching)

enum ArrowColor: String, Codable, CaseIterable {
    case white, red, blue, green, yellow, purple, orange
}

// MARK: - Grid Position

struct GridPosition: Hashable, Codable, Equatable {
    var row: Int
    var col: Int

    static func + (lhs: GridPosition, rhs: (row: Int, col: Int)) -> GridPosition {
        GridPosition(row: lhs.row + rhs.row, col: lhs.col + rhs.col)
    }
}

// MARK: - Arrow Model

final class Arrow: ObservableObject, Identifiable, Codable {
    let id: UUID
    var direction: ArrowDirection
    var position: GridPosition
    var type: ArrowType
    var color: ArrowColor
    var isRemoved: Bool
    var isHighlighted: Bool   // used for hint system
    var isWrong: Bool         // brief flash on invalid tap

    // Snake arrows occupy a list of positions
    var segments: [GridPosition]

    init(
        id: UUID = UUID(),
        direction: ArrowDirection,
        position: GridPosition,
        type: ArrowType = .standard,
        color: ArrowColor = .white,
        isRemoved: Bool = false
    ) {
        self.id = id
        self.direction = direction
        self.position = position
        self.type = type
        self.color = color
        self.isRemoved = isRemoved
        self.isHighlighted = false
        self.isWrong = false
        self.segments = [position]
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, direction, position, type, color, isRemoved, segments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        direction   = try c.decode(ArrowDirection.self, forKey: .direction)
        position    = try c.decode(GridPosition.self, forKey: .position)
        type        = try c.decodeIfPresent(ArrowType.self, forKey: .type) ?? .standard
        color       = try c.decodeIfPresent(ArrowColor.self, forKey: .color) ?? .white
        isRemoved   = try c.decodeIfPresent(Bool.self, forKey: .isRemoved) ?? false
        segments    = try c.decodeIfPresent([GridPosition].self, forKey: .segments) ?? []
        isHighlighted = false
        isWrong     = false
        if segments.isEmpty { segments = [position] }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(direction, forKey: .direction)
        try c.encode(position, forKey: .position)
        try c.encode(type, forKey: .type)
        try c.encode(color, forKey: .color)
        try c.encode(isRemoved, forKey: .isRemoved)
        try c.encode(segments, forKey: .segments)
    }

    /// Returns a deep copy of this arrow (used for undo stack)
    func copy() -> Arrow {
        let a = Arrow(id: id, direction: direction, position: position,
                      type: type, color: color, isRemoved: isRemoved)
        a.segments = segments
        return a
    }
}

// MARK: - Feature 3: Rotatable Arrow Support

extension Arrow {
    /// All clockwise-rotation steps: up→right→down→left→up
    static let cardinalRotationOrder: [ArrowDirection] = [.up, .right, .down, .left]
    /// All 8-direction clockwise steps
    static let fullRotationOrder: [ArrowDirection] = [
        .up, .upRight, .right, .downRight, .down, .downLeft, .left, .upLeft
    ]

    /// Rotates a rotatable arrow one step clockwise.
    /// No-op for non-rotatable arrows.
    func rotateClockwise(diagonalsEnabled: Bool = false) {
        guard type == .rotatable else { return }
        let order = diagonalsEnabled ? Arrow.fullRotationOrder : Arrow.cardinalRotationOrder
        guard let idx = order.firstIndex(of: direction) else { return }
        direction = order[(idx + 1) % order.count]
    }

    /// Rotates a rotatable arrow one step counter-clockwise.
    func rotateCounterClockwise(diagonalsEnabled: Bool = false) {
        guard type == .rotatable else { return }
        let order = diagonalsEnabled ? Arrow.fullRotationOrder : Arrow.cardinalRotationOrder
        guard let idx = order.firstIndex(of: direction) else { return }
        direction = order[(idx + order.count - 1) % order.count]
    }
}

// MARK: - Feature 4: Snake Arrow Support

extension Arrow {
    /// Whether this arrow spans multiple grid cells.
    var isSnake: Bool { type == .snake && segments.count > 1 }

    /// Add a segment position to a snake arrow.
    func addSegment(_ position: GridPosition) {
        guard type == .snake else { return }
        if !segments.contains(position) { segments.append(position) }
    }

    /// The head segment (the cell the arrow "faces" from).
    var head: GridPosition { segments.first ?? position }

    /// The tail segment (last occupied cell).
    var tail: GridPosition { segments.last ?? position }
}
