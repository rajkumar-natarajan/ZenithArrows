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
    let fromPosition: GridPosition
    let gridSnapshot: GridModel   // full grid state before move
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
    @Published var highlightedArrowID: UUID? = nil   // hint highlight
    @Published var wrongTapArrowID: UUID? = nil      // brief error flash

    // MARK: Level Info
    private(set) var levelDefinition: LevelDefinition
    private var timer: AnyCancellable?

    // MARK: Undo Stack (max 10)
    private var undoStack: [MoveRecord] = []
    private let maxUndoDepth = 10

    // MARK: All arrows (alive + removed, for rendering removed animations)
    private(set) var allArrows: [Arrow] = []

    init(levelDefinition: LevelDefinition) {
        self.levelDefinition = levelDefinition
        let g = GridModel(rows: levelDefinition.gridRows, cols: levelDefinition.gridCols)
        self.grid = g
        self.buildGrid()
    }

    // MARK: - Grid Initialisation

    private func buildGrid() {
        grid = GridModel(rows: levelDefinition.gridRows, cols: levelDefinition.gridCols)
        allArrows = []

        // Place obstacles first
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

        // Place arrows
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
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase == .playing else { return }
                self.elapsedTime += 1
            }
    }

    func stopTimer() { timer?.cancel() }

    // MARK: - Tap Handling

    /// Main entry point called by the view when user taps a grid cell
    func handleTap(at position: GridPosition, moveValidator: MoveValidator) {
        guard phase == .playing,
              let arrow = grid.arrow(at: position),
              !arrow.isRemoved else { return }

        if let path = moveValidator.validateMove(arrow: arrow, in: grid) {
            commitMove(arrow: arrow, path: path)
        } else {
            // Wrong tap penalty
            registerWrongTap(arrowID: arrow.id)
        }
    }

    private func commitMove(arrow: Arrow, path: SlidePath) {
        // Save undo snapshot before mutation
        pushUndo(arrowID: arrow.id)

        moves += 1
        phase = .animating

        // The animation layer (GameScene/ArrowNode) observes isRemoved
        // After animation completes, call finaliseRemoval()
        arrow.isRemoved = true
        grid.remove(arrowID: arrow.id)

        // Check win condition
        if grid.activeArrows.isEmpty {
            let stars = levelDefinition.starRating(
                moves: moves,
                time: elapsedTime,
                mistakes: mistakes
            )
            phase = .levelComplete(stars: stars)
            stopTimer()
        }
    }

    /// Called by animation layer when slide-out animation finishes
    func finaliseRemoval() {
        if case .animating = phase {
            phase = .playing
        }
    }

    // MARK: - Wrong Tap

    private func registerWrongTap(arrowID: UUID) {
        mistakes += 1
        lives = max(0, lives - 1)
        wrongTapArrowID = arrowID

        // Clear after brief flash (handled by view)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
            wrongTapArrowID = nil
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
        moves = max(0, moves - 1)

        // Re-sync allArrows with the restored grid snapshot
        allArrows = grid.activeArrows
    }

    private func pushUndo(arrowID: UUID) {
        let record = MoveRecord(
            arrowID: arrowID,
            fromPosition: grid.arrowPositions[arrowID] ?? GridPosition(row: 0, col: 0),
            gridSnapshot: grid.copy()
        )
        undoStack.append(record)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst()
        }
    }

    var canUndo: Bool { !undoStack.isEmpty && phase == .playing }

    // MARK: - Restart

    func restart() {
        stopTimer()
        moves = 0
        mistakes = 0
        lives = 3
        elapsedTime = 0
        undoStack = []
        highlightedArrowID = nil
        wrongTapArrowID = nil
        buildGrid()
        phase = .playing
        startTimer()
    }

    // MARK: - Pause / Resume

    func pause() { guard phase == .playing else { return }; phase = .paused; stopTimer() }
    func resume() { guard phase == .paused else { return }; phase = .playing; startTimer() }

    // MARK: - Hint

    func useHint(hintEngine: HintEngine) {
        guard hintsRemaining > 0, phase == .playing else { return }
        if let id = hintEngine.nextSafeMove(in: grid) {
            hintsRemaining -= 1
            highlightedArrowID = id
            // Auto-clear after 3 seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if highlightedArrowID == id { highlightedArrowID = nil }
            }
        }
    }
}
