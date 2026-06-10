// GameState.swift
// ZenithArrows
// Observable game session state — source of truth for a live level.

import Foundation
import Combine

// MARK: - Game Phase

enum GamePhase: Equatable {
    case idle
    case playing
    case animating          // Arrow slide in progress (blocks input)
    case paused
    case levelComplete(stars: Int)
    case levelFailed        // Out of lives
    case tutorial(step: Int)
}

// MARK: - Move Record (for undo)

struct MoveRecord {
    let arrowID: UUID
    let movesAtTime: Int
    let mistakesAtTime: Int
    let gridSnapshot: GridModel
}

// MARK: - GameState

@MainActor
final class GameState: ObservableObject {

    // MARK: Published State
    @Published var grid: GridModel
    @Published var phase: GamePhase = .idle
    @Published var moves: Int = 0
    @Published var mistakes: Int = 0
    @Published var lives: Int = 3
    @Published var hintsRemaining: Int = 3
    @Published var elapsedTime: TimeInterval = 0
    @Published var highlightedArrowID: UUID? = nil
    @Published var wrongTapArrowID: UUID? = nil
    @Published var lastRemovedArrowID: UUID? = nil  // for slide animation trigger

    // MARK: Level Info
    private(set) var levelDefinition: LevelDefinition
    private var timer: AnyCancellable?

    // MARK: Undo Stack (max 10)
    private var undoStack: [MoveRecord] = []
    private let maxUndoDepth = 10

    // MARK: Arrow list (for scene rebuild)
    private(set) var allArrows: [Arrow] = []

    // Tracks IDs of arrows committed in the current animation frame
    private var pendingRemovalIDs: Set<UUID> = []

    init(levelDefinition: LevelDefinition) {
        self.levelDefinition = levelDefinition
        self.grid = GridModel(rows: levelDefinition.gridRows,
                              cols: levelDefinition.gridCols)
        buildGrid()
    }

    // MARK: - Grid Initialisation

    private func buildGrid() {
        grid = GridModel(rows: levelDefinition.gridRows, cols: levelDefinition.gridCols)
        allArrows = []
        pendingRemovalIDs = []

        for op in levelDefinition.obstacles {
            let obs = Obstacle(
                id: UUID(),
                position: GridPosition(row: op.row, col: op.col),
                kind: op.kind,
                portalID: op.portalID,
                portalColor: op.portalColor
            )
            grid.place(obstacle: obs)
        }

        for ap in levelDefinition.arrows {
            let arrow = Arrow(
                direction: ap.direction,
                position: GridPosition(row: ap.row, col: ap.col),
                type: ap.type,
                color: ap.color
            )
            allArrows.append(arrow)
            grid.place(arrow: arrow)
        }
    }

    // MARK: - Timer

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase == .playing else { return }
                self.elapsedTime += 1
            }
    }

    func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Tap Handling

    /// Returns the validated SlidePath if the tap is legal, otherwise nil.
    /// Also fires wrong-tap penalty if arrow exists but is blocked.
    @discardableResult
    func handleTap(at position: GridPosition, moveValidator: MoveValidator) -> SlidePath? {
        guard phase == .playing,
              !pendingRemovalIDs.contains(where: { _ in false }), // always passes
              let arrow = grid.arrow(at: position),
              !arrow.isRemoved,
              !pendingRemovalIDs.contains(arrow.id) else { return nil }

        if let path = moveValidator.validateMove(arrow: arrow, in: grid) {
            commitMove(arrow: arrow, path: path)
            return path
        } else {
            registerWrongTap(arrowID: arrow.id)
            return nil
        }
    }

    private func commitMove(arrow: Arrow, path: SlidePath) {
        pushUndo(arrowID: arrow.id)
        moves += 1
        phase = .animating
        pendingRemovalIDs.insert(arrow.id)

        arrow.isRemoved = true
        grid.remove(arrowID: arrow.id)
        lastRemovedArrowID = arrow.id

        // Win check: if no active arrows remain, declare victory
        if grid.activeArrows.isEmpty {
            let stars = levelDefinition.starRating(
                moves: moves,
                time: elapsedTime,
                mistakes: mistakes
            )
            // Let animation finish first, then transition (handled by finaliseRemoval)
            // Store stars for later
            _pendingWinStars = stars
        }
    }

    private var _pendingWinStars: Int? = nil

    /// Called by the animation layer when the slide-out finishes.
    func finaliseRemoval(arrowID: UUID) {
        pendingRemovalIDs.remove(arrowID)
        if let stars = _pendingWinStars, pendingRemovalIDs.isEmpty {
            _pendingWinStars = nil
            phase = .levelComplete(stars: stars)
            stopTimer()
        } else if pendingRemovalIDs.isEmpty {
            if case .animating = phase { phase = .playing }
        }
    }

    // MARK: - Wrong Tap

    private func registerWrongTap(arrowID: UUID) {
        mistakes += 1
        lives = max(0, lives - 1)
        wrongTapArrowID = arrowID

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if wrongTapArrowID == arrowID { wrongTapArrowID = nil }
        }

        if lives == 0 {
            phase = .levelFailed
            stopTimer()
        }
    }

    // MARK: - Undo

    func undo() {
        guard !undoStack.isEmpty, phase == .playing else { return }
        let record = undoStack.removeLast()
        grid = record.gridSnapshot
        moves = record.movesAtTime
        mistakes = record.mistakesAtTime
        lives = min(3, lives + 1) // restore one life on undo
        allArrows = grid.activeArrows
        highlightedArrowID = nil
    }

    private func pushUndo(arrowID: UUID) {
        let record = MoveRecord(
            arrowID: arrowID,
            movesAtTime: moves,
            mistakesAtTime: mistakes,
            gridSnapshot: grid.copy()
        )
        undoStack.append(record)
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
    }

    var canUndo: Bool { !undoStack.isEmpty && phase == .playing }

    // MARK: - Restart

    func restart() {
        stopTimer()
        moves = 0; mistakes = 0; lives = 3; elapsedTime = 0
        undoStack = []; pendingRemovalIDs = []
        highlightedArrowID = nil; wrongTapArrowID = nil
        _pendingWinStars = nil
        buildGrid()
        phase = .playing
        startTimer()
    }

    // MARK: - Pause / Resume

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        stopTimer()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        startTimer()
    }

    // MARK: - Hint

    func useHint(hintEngine: HintEngine) {
        guard hintsRemaining > 0, phase == .playing else { return }
        if let id = hintEngine.nextSafeMove(in: grid) {
            hintsRemaining -= 1
            highlightedArrowID = id
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if highlightedArrowID == id { highlightedArrowID = nil }
            }
        }
    }

    // MARK: - Moveable Arrow Count (for HUD hint)

    func moveableArrowCount(validator: MoveValidator) -> Int {
        validator.moveableArrows(in: grid).count
    }
}
