// LevelModel.swift
// ZenithArrows
// Defines a level's static data (layout, metadata, obstacles).

import Foundation

// MARK: - World / Chapter grouping

struct World: Codable, Identifiable {
    let id: Int
    let name: String
    let themeKey: String          // maps to ThemeManager theme names
    let description: String
    var levels: [LevelDefinition]
    let requiredStarsToUnlock: Int
    var isUnlocked: Bool
}

// MARK: - Difficulty

enum LevelDifficulty: String, Codable {
    case tutorial, easy, medium, hard, expert, zen
}

// MARK: - Arrow Placement (static definition in a level file)

struct ArrowPlacement: Codable {
    let row: Int
    let col: Int
    let direction: ArrowDirection
    var type: ArrowType
    var color: ArrowColor

    init(row: Int, col: Int, direction: ArrowDirection,
         type: ArrowType = .standard, color: ArrowColor = .white) {
        self.row = row; self.col = col; self.direction = direction
        self.type = type; self.color = color
    }

    private enum CodingKeys: String, CodingKey {
        case row, col, direction, type, color
    }

    // Custom decoder: type and color are optional in JSON (omitted in most level files)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        row       = try c.decode(Int.self,            forKey: .row)
        col       = try c.decode(Int.self,            forKey: .col)
        direction = try c.decode(ArrowDirection.self, forKey: .direction)
        type      = try c.decodeIfPresent(ArrowType.self,  forKey: .type)  ?? .standard
        color     = try c.decodeIfPresent(ArrowColor.self, forKey: .color) ?? .white
    }
}

// MARK: - Level Definition (JSON-decodable)

struct LevelDefinition: Codable, Identifiable {
    let id: String                     // e.g. "w1_l001"
    let worldID: Int
    let index: Int                     // position within world (1-based)
    let gridRows: Int
    let gridCols: Int
    let arrows: [ArrowPlacement]
    let obstacles: [ObstaclePlacement]
    let difficulty: LevelDifficulty
    let parMoves: Int                  // moves needed for 3-star
    let parTime: TimeInterval          // seconds for 3-star bonus
    let diagonalsEnabled: Bool
    let title: String?                 // optional flavour name
    var bestStars: Int                 // 0-3, persisted separately
    var isUnlocked: Bool

    // Provides 3-star thresholds
    func starRating(moves: Int, time: TimeInterval, mistakes: Int) -> Int {
        if mistakes == 0 && moves <= parMoves && time <= parTime { return 3 }
        if mistakes <= 1 && moves <= parMoves + 3                { return 2 }
        return 1
    }

    enum CodingKeys: String, CodingKey {
        case id, worldID, index, gridRows, gridCols, arrows, obstacles,
             difficulty, parMoves, parTime, diagonalsEnabled, title
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        worldID          = try c.decode(Int.self, forKey: .worldID)
        index            = try c.decode(Int.self, forKey: .index)
        gridRows         = try c.decode(Int.self, forKey: .gridRows)
        gridCols         = try c.decode(Int.self, forKey: .gridCols)
        arrows           = try c.decode([ArrowPlacement].self, forKey: .arrows)
        obstacles        = try c.decodeIfPresent([ObstaclePlacement].self, forKey: .obstacles) ?? []
        difficulty       = try c.decodeIfPresent(LevelDifficulty.self, forKey: .difficulty) ?? .easy
        parMoves         = try c.decodeIfPresent(Int.self, forKey: .parMoves) ?? arrows.count
        parTime          = try c.decodeIfPresent(TimeInterval.self, forKey: .parTime) ?? 120
        diagonalsEnabled = try c.decodeIfPresent(Bool.self, forKey: .diagonalsEnabled) ?? false
        title            = try c.decodeIfPresent(String.self, forKey: .title)
        bestStars        = 0
        isUnlocked       = false
    }

    /// Direct initialiser used by LevelGenerator (no JSON round-trip needed)
    init(id: String, worldID: Int, index: Int,
         gridRows: Int, gridCols: Int,
         arrows: [ArrowPlacement], obstacles: [ObstaclePlacement] = [],
         difficulty: LevelDifficulty = .easy,
         parMoves: Int, parTime: TimeInterval = 120,
         diagonalsEnabled: Bool = false, title: String? = nil) {
        self.id = id; self.worldID = worldID; self.index = index
        self.gridRows = gridRows; self.gridCols = gridCols
        self.arrows = arrows; self.obstacles = obstacles
        self.difficulty = difficulty; self.parMoves = parMoves; self.parTime = parTime
        self.diagonalsEnabled = diagonalsEnabled; self.title = title
        self.bestStars = 0; self.isUnlocked = false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(worldID, forKey: .worldID)
        try c.encode(index, forKey: .index)
        try c.encode(gridRows, forKey: .gridRows)
        try c.encode(gridCols, forKey: .gridCols)
        try c.encode(arrows, forKey: .arrows)
        try c.encode(obstacles, forKey: .obstacles)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(parMoves, forKey: .parMoves)
        try c.encode(parTime, forKey: .parTime)
        try c.encode(diagonalsEnabled, forKey: .diagonalsEnabled)
        try c.encodeIfPresent(title, forKey: .title)
    }
}

// MARK: - Obstacle Placement (level file)

struct ObstaclePlacement: Codable {
    let row: Int
    let col: Int
    let kind: Obstacle.ObstacleKind
    var portalID: Int?
    var portalColor: ArrowColor?
}
