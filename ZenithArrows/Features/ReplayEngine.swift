// ReplayEngine.swift
// ZenithArrows
//
// Feature 5: Replay / Solution Playback.
//
// Supports two replay modes:
//
// ## History Replay
// Records each `ReplayStep` during live play via `record(arrow:stepIndex:)`.
// `startHistoryReplay(intervalSeconds:)` plays back the steps the player
// actually made, highlighting each arrow in sequence.
//
// ## Optimal Replay
// `startOptimalReplay(grid:hintEngine:intervalSeconds:)` calls
// `HintEngine.solveOrder` to compute the best solution and replays it
// from the post-completion grid state.
//
// ## Integration
//
// `GameState` owns the `ReplayEngine`.  `GameBoardView` passes it to
// `EndLevelView`, which wires the "Watch Solution" button.
// `onStepExecuted` closure fires per step so `GameScene` can animate
// the highlight; `onReplayComplete` fires when all steps finish.
//
// ## Thread Safety
//
// Decorated `@MainActor`; the async step loop uses structured concurrency
// (`Task`) and checks `Task.isCancelled` before each step.

import Foundation
import Combine

// MARK: - Replay Step

struct ReplayStep: Identifiable {
    let id = UUID()
    let arrowID: UUID
    let positionBefore: GridPosition
    let direction: ArrowDirection
    let slideIndex: Int           // step number (1-based)
}

// MARK: - ReplayEngine

@MainActor
final class ReplayEngine: ObservableObject {

    @Published private(set) var isReplaying: Bool = false
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var steps: [ReplayStep] = []
    @Published var highlightedArrowID: UUID? = nil

    private var replayTask: Task<Void, Never>? = nil
    var onStepExecuted: ((ReplayStep) -> Void)? = nil
    var onReplayComplete: (() -> Void)? = nil

    // MARK: - Recording

    /// Records a player move for history replay.
    func record(arrow: Arrow, stepIndex: Int) {
        let step = ReplayStep(
            arrowID: arrow.id,
            positionBefore: arrow.position,
            direction: arrow.direction,
            slideIndex: stepIndex
        )
        steps.append(step)
    }

    func clearRecording() {
        steps.removeAll()
        currentStepIndex = 0
    }

    // MARK: - Optimal Solution Replay

    /// Builds replay steps from the hint engine's solve order and starts playback.
    func startOptimalReplay(grid: GridModel, hintEngine: HintEngine, intervalSeconds: Double = 0.8) {
        guard !isReplaying else { return }
        guard let order = hintEngine.solveOrder(arrows: grid.activeArrows, grid: grid) else { return }

        // Build steps from solve order
        var replaySteps: [ReplayStep] = []
        for (index, arrowID) in order.enumerated() {
            guard let arrow = grid.activeArrows.first(where: { $0.id == arrowID }) else { continue }
            replaySteps.append(ReplayStep(
                arrowID: arrowID,
                positionBefore: arrow.position,
                direction: arrow.direction,
                slideIndex: index + 1
            ))
        }

        steps = replaySteps
        currentStepIndex = 0
        isReplaying = true
        playSteps(interval: intervalSeconds)
    }

    /// Replays the recorded player history.
    func startHistoryReplay(intervalSeconds: Double = 0.7) {
        guard !isReplaying, !steps.isEmpty else { return }
        isReplaying = true
        currentStepIndex = 0
        playSteps(interval: intervalSeconds)
    }

    func stop() {
        replayTask?.cancel()
        replayTask = nil
        isReplaying = false
        highlightedArrowID = nil
    }

    // MARK: - Private

    private func playSteps(interval: Double) {
        replayTask?.cancel()
        replayTask = Task { @MainActor in
            for (i, step) in steps.enumerated() {
                guard !Task.isCancelled else { break }
                currentStepIndex = i
                highlightedArrowID = step.arrowID
                onStepExecuted?(step)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            highlightedArrowID = nil
            isReplaying = false
            onReplayComplete?()
        }
    }
}
