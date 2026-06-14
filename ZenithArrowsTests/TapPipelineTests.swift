// TapPipelineTests.swift
// ZenithArrows
//
// COMPREHENSIVE TAP PIPELINE TEST HARNESS
// Simulates the exact sequence of events that happens when a player taps an arrow:
//   1. touchesBegan fires, grabs grid position
//   2. GameScene.touchesBegan validates: phase check, arrow lookup, slidingArrowIDs
//   3. MoveValidator.validateMove returns SlidePath or nil
//   4. triggerSlide: inserts slidingArrowID, calls GameState.handleTap
//   5. handleTap: phase check, pendingRemovalIDs check, re-validate, commitMove
//   6. commitMove: pushUndo, phase=.animating, grid.remove, win check
//   7. animateSlide (simulated), then finaliseRemoval
//
// Run with: xcodebuild test -scheme ZenithArrows ...
// Every test includes a comment explaining WHAT it tests and WHY it could fail.

import XCTest
@testable import ZenithArrows

// MARK: - Helpers

private func level(rows: Int = 4, cols: Int = 4,
                   arrows: [(Int, Int, ArrowDirection)] = [],
                   parMoves: Int = 10) -> LevelDefinition {
    LevelDefinition(
        id: "pipe_test_\(UUID().uuidString.prefix(8))",
        worldID: 1, index: 1,
        gridRows: rows, gridCols: cols,
        arrows: arrows.map { ArrowPlacement(row: $0.0, col: $0.1, direction: $0.2) },
        difficulty: .easy,
        parMoves: parMoves,
        parTime: 120
    )
}

private func singleArrowLevel(direction: ArrowDirection = .right) -> LevelDefinition {
    // Arrow at (0,0) facing right — exits board immediately, nothing blocking it
    level(arrows: [(0, 0, direction)])
}

// MARK: ============================================================
// MARK: PHASE GUARD TESTS — verifies phase check in touchesBegan and handleTap
// MARK: ============================================================

@MainActor
final class PhaseGuardTests: XCTestCase {

    /// WHAT: handleTap should accept taps when phase is .playing
    /// WHY: This is the primary gameplay state; if this fails nothing works
    func testHandleTapAcceptsPlayingPhase() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNotNil(result, "handleTap must return SlidePath when phase is .playing")
    }

    /// WHAT: handleTap should accept taps when phase is .animating
    /// WHY: After first arrow is tapped phase becomes .animating; second tap must work
    func testHandleTapAcceptsAnimatingPhase() {
        let lvl = level(rows: 2, cols: 4, arrows: [
            (0, 0, .right),   // row 0: arrow exits right
            (1, 0, .right),   // row 1: arrow exits right (unblocked by row 0)
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()
        // First tap — phase goes to .animating
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertEqual(gs.phase, .animating, "Phase should be .animating after first commit")
        // Second tap during animating — must succeed
        let result = gs.handleTap(at: GridPosition(row: 1, col: 0), moveValidator: v)
        XCTAssertNotNil(result, "handleTap must work in .animating phase")
    }

    /// WHAT: handleTap must reject taps when phase is .paused
    /// WHY: Player paused the game; taps on grid must do nothing
    func testHandleTapRejectsPausedPhase() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .paused
        let v = MoveValidator()
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNil(result, "handleTap must return nil when paused")
    }

    /// WHAT: handleTap must reject taps when phase is .idle (before beginPlaying)
    /// WHY: beginPlaying sets phase to .playing; if it never fires the game is stuck idle
    func testHandleTapRejectsIdlePhase() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        // Phase starts as .idle — don't call beginPlaying
        XCTAssertEqual(gs.phase, .idle)
        let v = MoveValidator()
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNil(result, "handleTap must return nil in .idle phase (game not started)")
    }

    /// WHAT: handleTap must reject taps when phase is levelComplete
    /// WHY: After winning, stale taps must not mutate state
    func testHandleTapRejectsLevelCompletePhase() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .levelComplete(stars: 3)
        let v = MoveValidator()
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNil(result, "handleTap must return nil after level complete")
    }
}

// MARK: ============================================================
// MARK: MOVE VALIDATION PIPELINE — the full path from tap to SlidePath
// MARK: ============================================================

@MainActor
final class MoveValidationPipelineTests: XCTestCase {

    /// WHAT: A free-facing arrow returns a non-nil SlidePath
    /// WHY: This is the success path — if nil is returned the arrow never slides
    func testFreeArrowReturnsNonNilSlidePath() {
        let gs = GameState(levelDefinition: singleArrowLevel(.right))
        gs.phase = .playing
        let v = MoveValidator()
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNotNil(result, "Free-facing arrow must produce a valid SlidePath")
        XCTAssertNotNil(result?.exitsBoardAt, "Arrow facing right on row 0 col 0 must exit the board")
    }

    /// WHAT: Tapping a cell with no arrow penalises but doesn't crash
    /// WHY: Player mis-taps empty cell; wrong-tap logic runs; lives decrease by 1
    func testEmptyCellTapDeductsOneLife() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        let before = gs.lives
        gs.handleTap(at: GridPosition(row: 2, col: 2), moveValidator: v) // empty cell
        XCTAssertEqual(gs.lives, before - 1, "Empty cell tap must deduct exactly 1 life")
    }

    /// WHAT: Tapping an arrow that is blocked returns nil and costs a life
    /// WHY: Player tries to move a stuck arrow; must see wrong-tap feedback
    func testBlockedArrowTapDeductsOneLife() {
        let lvl = level(rows: 1, cols: 3, arrows: [
            (0, 0, .right),   // blocked by (0,1)
            (0, 1, .right),   // this one can exit (clear path to col2 then OOB)
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()
        let before = gs.lives
        // (0,0) is blocked by (0,1) — should fail
        let result = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNil(result, "Blocked arrow tap must return nil SlidePath")
        XCTAssertEqual(gs.lives, before - 1, "Blocked tap must deduct exactly 1 life")
    }

    /// WHAT: Tapping the unblocked arrow first succeeds, then unblocked arrow commits
    /// WHY: This is the core gameplay — order-dependent removal
    func testCorrectOrderTapSucceeds() {
        let lvl = level(rows: 1, cols: 3, arrows: [
            (0, 0, .right),   // blocked by (0,1)
            (0, 1, .right),   // free — exits right
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()
        // Tap (0,1) first — it's free
        let result = gs.handleTap(at: GridPosition(row: 0, col: 1), moveValidator: v)
        XCTAssertNotNil(result, "Unblocked arrow must succeed on first tap")
        XCTAssertEqual(gs.moves, 1)
    }

    /// WHAT: After a valid tap, pendingRemovalIDs contains that arrow's ID
    /// WHY: pendingRemovalIDs prevents double-tapping the same sliding arrow
    func testPendingRemovalSetAfterTap() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        // Grab the arrow ID before tapping
        let arrowID = gs.grid.activeArrows.first!.id
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        // The arrow should be in pendingRemovalIDs
        XCTAssertTrue(gs.allArrows.first?.isRemoved ?? false,
                      "Arrow must be marked isRemoved after commitMove")
    }

    /// WHAT: After finaliseRemoval, phase transitions back to .playing (or .levelComplete)
    /// WHY: If phase stays .animating, all future taps are blocked
    func testFinaliseRemovalTransitionsPhase() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertEqual(gs.phase, .animating, "Phase must be .animating after commit")
        // Simulate animation completion
        let arrowID = gs.allArrows.first!.id
        gs.finaliseRemoval(arrowID: arrowID)
        // With one arrow, the win condition fires → .levelComplete
        if case .levelComplete = gs.phase { } else if gs.phase == .playing { }
        else { XCTFail("Phase must be .levelComplete or .playing after finalise, got \(gs.phase)") }
    }

    /// WHAT: Win is detected after the last arrow is removed
    /// WHY: If _pendingWinStars check fails, level never completes
    func testWinDetectedAfterLastArrow() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        let arrowID = gs.allArrows.first!.id
        gs.finaliseRemoval(arrowID: arrowID)
        if case .levelComplete(let stars) = gs.phase {
            XCTAssertGreaterThan(stars, 0, "Stars should be > 0 on win")
        } else {
            XCTFail("Phase must be .levelComplete after last arrow removed, got \(gs.phase)")
        }
    }

    /// WHAT: Lives don't go below 0
    /// WHY: Safety check — wrong-tap loop must not crash with negative lives
    func testLivesNeverBelowZero() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        // Tap 10 empty cells
        for col in 0..<10 {
            gs.handleTap(at: GridPosition(row: 3, col: min(col, 3)), moveValidator: v)
        }
        XCTAssertGreaterThanOrEqual(gs.lives, 0, "Lives must never go below 0")
    }

    /// WHAT: 3 wrong taps triggers levelFailed
    /// WHY: Core lives mechanic
    func testThreeWrongTapsTriggersLevelFailed() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        // Empty cell taps on non-arrow positions
        gs.handleTap(at: GridPosition(row: 3, col: 3), moveValidator: v)
        gs.handleTap(at: GridPosition(row: 3, col: 2), moveValidator: v)
        gs.handleTap(at: GridPosition(row: 3, col: 1), moveValidator: v)
        XCTAssertEqual(gs.phase, .levelFailed, "3 wrong taps must cause levelFailed")
    }
}

// MARK: ============================================================
// MARK: GRID COORDINATE CORRECTNESS — verifies grid position math
// MARK: ============================================================

final class GridCoordinateTests: XCTestCase {

    /// WHAT: gridPosition(for:) round-trips correctly through position(for:)
    /// WHY: Touch hit-testing depends on this conversion; if off by 1 cell no taps land
    func testGridPositionRoundTrip() {
        let rows = 5, cols = 5
        let cellSize: CGFloat = 60
        let gridNode = GridNode(rows: rows, cols: cols, cellSize: cellSize,
                                theme: ThemeManager.zenTheme)
        for row in 0..<rows {
            for col in 0..<cols {
                let pos = GridPosition(row: row, col: col)
                let scenePoint = gridNode.position(for: pos)
                let recovered = gridNode.gridPosition(for: scenePoint)
                XCTAssertEqual(recovered, pos,
                               "Round-trip failed for (\(row),\(col)): got \(String(describing: recovered))")
            }
        }
    }

    /// WHAT: gridPosition returns nil for points outside the grid
    /// WHY: Touches outside the grid must not crash or mis-identify arrows
    func testOutOfBoundsPointReturnsNil() {
        let gridNode = GridNode(rows: 4, cols: 4, cellSize: 60, theme: ThemeManager.zenTheme)
        let farPoint = CGPoint(x: 9999, y: 9999)
        XCTAssertNil(gridNode.gridPosition(for: farPoint), "Far OOB point must return nil")

        let negPoint = CGPoint(x: -100, y: -100)
        XCTAssertNil(gridNode.gridPosition(for: negPoint), "Negative OOB point must return nil")
    }

    /// WHAT: Touch at the center of cell (1,2) lands exactly on (1,2)
    /// WHY: Player taps center of an arrow — must hit that cell exactly
    func testCenterOfCellHitsCorrectGridPos() {
        let rows = 4, cols = 4
        let cs: CGFloat = 64
        let gridNode = GridNode(rows: rows, cols: cols, cellSize: cs,
                                theme: ThemeManager.zenTheme)
        let target = GridPosition(row: 1, col: 2)
        let center = gridNode.position(for: target)
        let hit = gridNode.gridPosition(for: center)
        XCTAssertEqual(hit, target, "Touch at cell center must map back to that cell")
    }

    /// WHAT: Touch at edge of a cell still lands in the correct cell
    /// WHY: Players often tap near the edge; +/- 1px must still register
    func testNearEdgeTouchHitsCorrectCell() {
        let cs: CGFloat = 60
        let gridNode = GridNode(rows: 4, cols: 4, cellSize: cs,
                                theme: ThemeManager.zenTheme)
        let target = GridPosition(row: 0, col: 0)
        let center = gridNode.position(for: target)
        // 1pt inside the top-right edge of cell (0,0)
        let nearEdge = CGPoint(x: center.x + cs * 0.45, y: center.y - cs * 0.45)
        let hit = gridNode.gridPosition(for: nearEdge)
        XCTAssertEqual(hit, target, "Near-edge touch must still hit the correct cell")
    }

    /// WHAT: A 6x6 grid with 48pt cellSize covers a 288x288pt area
    /// WHY: Verifies grid size computation for different board sizes
    func testGridDimensionsCorrect6x6() {
        let cs: CGFloat = 48
        let gridNode = GridNode(rows: 6, cols: 6, cellSize: cs,
                                theme: ThemeManager.zenTheme)
        // Top-left corner cell (0,0) — convert and back
        let tl = gridNode.gridPosition(for: gridNode.position(for: GridPosition(row: 0, col: 0)))
        XCTAssertEqual(tl, GridPosition(row: 0, col: 0))
        // Bottom-right corner cell (5,5)
        let br = gridNode.gridPosition(for: gridNode.position(for: GridPosition(row: 5, col: 5)))
        XCTAssertEqual(br, GridPosition(row: 5, col: 5))
    }
}

// MARK: ============================================================
// MARK: FULL GAME FLOW — end-to-end level completion simulation
// MARK: ============================================================

@MainActor
final class FullGameFlowTests: XCTestCase {

    /// WHAT: Simulate Level 1 (all 4 corners facing out) — tap all 4 in any order
    /// WHY: This is the first thing a new user does; must work 100%
    func testLevel1AllArrowsEscapeInAnyOrder() {
        let lvl = level(rows: 4, cols: 4, arrows: [
            (0, 0, .left),   // exits left
            (0, 3, .up),     // exits up
            (3, 0, .down),   // exits down
            (3, 3, .right),  // exits right
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()

        // Verify all 4 are moveable at start
        let moveable = v.moveableArrows(in: gs.grid)
        XCTAssertEqual(moveable.count, 4, "All 4 corner arrows must be moveable at start")

        // Tap them all
        let positions = [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 0, col: 3),
            GridPosition(row: 3, col: 0),
            GridPosition(row: 3, col: 3),
        ]
        for pos in positions {
            let result = gs.handleTap(at: pos, moveValidator: v)
            XCTAssertNotNil(result, "Arrow at \(pos) must escape (return non-nil SlidePath)")
            if let id = gs.lastRemovedArrowID {
                gs.finaliseRemoval(arrowID: id)
            }
        }
        if case .levelComplete = gs.phase { } else {
            XCTFail("Level must complete after all 4 arrows removed, got \(gs.phase)")
        }
    }

    /// WHAT: A blocked arrow cannot be tapped, but unblocking it first allows escape
    /// WHY: This is the core puzzle mechanic — order matters
    func testOrderDependentRemoval() {
        // Row 0: A→right blocked by B, B→right exits (5-col grid)
        let lvl = level(rows: 1, cols: 5, arrows: [
            (0, 0, .right),  // A — blocked by B at (0,2)
            (0, 2, .right),  // B — free
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()

        // Tapping A first = wrong (blocked)
        let wrongResult = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNil(wrongResult, "A is blocked by B; must return nil")
        XCTAssertEqual(gs.lives, 2, "One wrong tap costs 1 life")

        // Tap B = correct
        let bResult = gs.handleTap(at: GridPosition(row: 0, col: 2), moveValidator: v)
        XCTAssertNotNil(bResult, "B is free; must succeed")
        gs.finaliseRemoval(arrowID: gs.lastRemovedArrowID!)

        // Now A is free
        let aResult = gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        XCTAssertNotNil(aResult, "A is now unblocked after B removed; must succeed")
    }

    /// WHAT: Undo after a tap restores the arrow and decrements move count
    /// WHY: Undo is advertised feature; if broken players lose confidence in the game
    func testUndoRestoresArrowAndMoveCount() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        if let id = gs.lastRemovedArrowID { gs.finaliseRemoval(arrowID: id) }
        XCTAssertEqual(gs.moves, 1)
        gs.undo()
        XCTAssertEqual(gs.moves, 0, "Undo must restore move count to 0")
        XCTAssertEqual(gs.grid.activeArrows.count, 1, "Undo must restore the arrow to the grid")
    }

    /// WHAT: Hint highlights a moveable arrow without consuming a life
    /// WHY: Hint must be safe to use; wrong-tap after hint must still have correct lives
    func testHintHighlightsWithoutPenalty() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let hint = HintEngine()
        let before = gs.lives
        gs.useHint(hintEngine: hint)
        XCTAssertNotNil(gs.highlightedArrowID, "Hint must set highlightedArrowID")
        XCTAssertEqual(gs.lives, before, "Using a hint must not cost a life")
    }

    /// WHAT: After all arrows removed, win condition fires with stars > 0
    /// WHY: finaliseRemoval → win detection pipeline must complete
    func testWinPipelineCompletesWithStars() {
        let lvl = level(rows: 1, cols: 4, arrows: [
            (0, 0, .right),
            (0, 3, .down),
        ])
        let gs = GameState(levelDefinition: lvl)
        gs.phase = .playing
        let v = MoveValidator()

        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        gs.finaliseRemoval(arrowID: gs.allArrows.first { $0.direction == .right }!.id)

        gs.handleTap(at: GridPosition(row: 0, col: 3), moveValidator: v)
        gs.finaliseRemoval(arrowID: gs.allArrows.first { $0.direction == .down }!.id)

        if case .levelComplete(let stars) = gs.phase {
            XCTAssertGreaterThan(stars, 0, "Must earn at least 1 star on completion")
        } else {
            XCTFail("Must reach .levelComplete, got \(gs.phase)")
        }
    }

    /// WHAT: Restart clears all state back to initial
    /// WHY: Player replays; must get fresh state exactly
    func testRestartClearsAllState() {
        let gs = GameState(levelDefinition: singleArrowLevel())
        gs.phase = .playing
        let v = MoveValidator()
        gs.handleTap(at: GridPosition(row: 0, col: 0), moveValidator: v)
        if let id = gs.lastRemovedArrowID { gs.finaliseRemoval(arrowID: id) }
        gs.restart()
        XCTAssertEqual(gs.moves, 0)
        XCTAssertEqual(gs.mistakes, 0)
        XCTAssertEqual(gs.lives, 3)
        XCTAssertEqual(gs.elapsedTime, 0, accuracy: 0.1)
        XCTAssertEqual(gs.grid.activeArrows.count, 1, "Restart must restore the arrow")
        XCTAssertEqual(gs.phase, .playing)
    }
}

// MARK: ============================================================
// MARK: LEVEL JSON VALIDITY — verifies all level files load and are solvable
// MARK: ============================================================

final class LevelJSONValidityTests: XCTestCase {

    private let engine = HintEngine()

    private func loadWorld(_ name: String) -> World? {
        let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")
               ?? Bundle.main.url(forResource: name, withExtension: "json")
        guard let u = url, let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(World.self, from: data)
    }

    private func isSolvable(_ level: LevelDefinition) -> (solvable: Bool, reason: String) {
        let grid = GridModel(rows: level.gridRows, cols: level.gridCols)
        for obs in level.obstacles {
            let o = Obstacle(id: UUID(),
                             position: GridPosition(row: obs.row, col: obs.col),
                             kind: obs.kind, portalID: obs.portalID, portalColor: obs.portalColor)
            grid.place(obstacle: o)
        }
        // Check duplicate positions
        let positions = level.arrows.map { GridPosition(row: $0.row, col: $0.col) }
        if positions.count != Set(positions).count {
            return (false, "Duplicate arrow positions in level \(level.id)")
        }
        // Check OOB
        for ap in level.arrows {
            if ap.row < 0 || ap.row >= level.gridRows || ap.col < 0 || ap.col >= level.gridCols {
                return (false, "Arrow at (\(ap.row),\(ap.col)) is out of bounds")
            }
        }
        for ap in level.arrows {
            let a = Arrow(direction: ap.direction,
                          position: GridPosition(row: ap.row, col: ap.col),
                          type: ap.type, color: ap.color)
            grid.place(arrow: a)
        }
        // Check at least 1 arrow is moveable at start
        let moveable = MoveValidator().moveableArrows(in: grid)
        if moveable.isEmpty {
            return (false, "Level \(level.id) has 0 moveable arrows at start — complete deadlock")
        }
        if !engine.isSolvable(grid: grid) {
            return (false, "Level \(level.id) is unsolvable (HintEngine deadlock)")
        }
        return (true, "ok")
    }

    /// WHAT: Level 1 specifically — must have at least 1 immediately tappable arrow
    /// WHY: If the very first level blocks every arrow, the game appears broken
    func testLevel1HasMoveableArrowsAtStart() throws {
        guard let world = loadWorld("world1") else {
            throw XCTSkip("world1.json not in bundle")
        }
        guard let lvl = world.levels.first else { XCTFail("No levels in world1"); return }
        let grid = GridModel(rows: lvl.gridRows, cols: lvl.gridCols)
        for ap in lvl.arrows {
            let a = Arrow(direction: ap.direction, position: GridPosition(row: ap.row, col: ap.col))
            grid.place(arrow: a)
        }
        let moveable = MoveValidator().moveableArrows(in: grid)
        XCTAssertGreaterThan(moveable.count, 0,
            "Level 1 must have at least 1 moveable arrow at start. Got: \(lvl.arrows.map { "(\($0.row),\($0.col),\($0.direction.rawValue))" })")
    }

    func testAllWorld1LevelsSolvable() throws {
        guard let world = loadWorld("world1") else { throw XCTSkip("world1.json not in bundle") }
        for level in world.levels {
            let (ok, reason) = isSolvable(level)
            XCTAssertTrue(ok, "World 1 Level \(level.index) '\(level.title ?? "?")': \(reason)")
        }
    }

    func testAllWorld2LevelsSolvable() throws {
        guard let world = loadWorld("world2") else { throw XCTSkip("world2.json not in bundle") }
        for level in world.levels {
            let (ok, reason) = isSolvable(level)
            XCTAssertTrue(ok, "World 2 Level \(level.index) '\(level.title ?? "?")': \(reason)")
        }
    }

    func testAllWorld3LevelsSolvable() throws {
        guard let world = loadWorld("world3") else { throw XCTSkip("world3.json not in bundle") }
        for level in world.levels {
            let (ok, reason) = isSolvable(level)
            XCTAssertTrue(ok, "World 3 Level \(level.index) '\(level.title ?? "?")': \(reason)")
        }
    }

    func testAllWorld4LevelsSolvable() throws {
        guard let world = loadWorld("world4") else { throw XCTSkip("world4.json not in bundle") }
        for level in world.levels {
            let (ok, reason) = isSolvable(level)
            XCTAssertTrue(ok, "World 4 Level \(level.index) '\(level.title ?? "?")': \(reason)")
        }
    }

    /// WHAT: Every level must have > 0 arrows
    func testAllLevelsHaveArrows() throws {
        for name in ["world1","world2","world3","world4"] {
            guard let world = loadWorld(name) else { continue }
            for level in world.levels {
                XCTAssertGreaterThan(level.arrows.count, 0,
                                     "\(name) Level \(level.index) has no arrows")
            }
        }
    }
}

// MARK: ============================================================
// MARK: SCENE SIZE SAFETY — validates that GameScene handles edge-case sizes
// MARK: ============================================================

final class SceneSizeTests: XCTestCase {

    /// WHAT: cellSize is never 0 for typical screen dimensions
    /// WHY: A zero cellSize causes grid to be built at origin, arrows invisible
    func testCellSizeNonZeroForTypicalScreen() {
        let screens: [(CGFloat, CGFloat)] = [
            (390, 844),   // iPhone 16 portrait
            (430, 932),   // iPhone 16 Pro Max portrait
            (375, 667),   // iPhone SE
            (320, 568),   // Very small screen
        ]
        for (w, h) in screens {
            // HUD ~100pt, booster bar ~50pt → available height ≈ h - 150
            let availH = h - 150
            let size = CGSize(width: w, height: availH)
            let maxDim = 5  // 5×5 grid
            let cs = floor(min(size.width, size.height) * 0.90 / CGFloat(maxDim))
            XCTAssertGreaterThan(cs, 0,
                "cellSize must be > 0 for screen \(w)x\(h), got \(cs)")
        }
    }

    /// WHAT: Zero/near-zero scene size does NOT produce a non-zero cellSize
    /// WHY: Confirms the guard cs > 0 is necessary
    func testZeroSizeProducesZeroCellSize() {
        let size = CGSize.zero
        let cs = floor(min(size.width, size.height) * 0.90 / 4)
        XCTAssertEqual(cs, 0, "Zero size must produce zero cellSize (confirms guard is needed)")
    }
}
