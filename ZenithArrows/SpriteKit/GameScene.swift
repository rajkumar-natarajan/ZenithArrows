// GameScene.swift
// ZenithArrows
// Primary SpriteKit scene. Owns the grid node and all arrow nodes.
// Bridges between the SwiftUI GameState (model) and the SpriteKit render layer.

import SpriteKit
import Combine

final class GameScene: SKScene {

    // MARK: - Dependencies (injected before presentScene)
    var gameState: GameState!
    var moveValidator: MoveValidator!
    var hintEngine: HintEngine!
    var theme: GameTheme = ThemeManager.shared.current
    var hapticManager: HapticManager = HapticManager.shared
    var audioManager: AudioManager = AudioManager.shared

    // MARK: - Scene Nodes
    private var gridNode: GridNode!
    private var arrowNodes: [UUID: ArrowNode] = [:]

    // MARK: - State Tracking
    private var cancellables = Set<AnyCancellable>()
    private var pendingSlideArrowID: UUID?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        setupGrid()
        placeAllArrows()
        observeGameState()
    }

    // MARK: - Setup

    private func setupGrid() {
        let def = gameState.levelDefinition
        let maxDim = max(def.gridRows, def.gridCols)
        let availableSize = min(size.width, size.height) * 0.92
        let cellSize = floor(availableSize / CGFloat(maxDim))

        gridNode = GridNode(rows: def.gridRows, cols: def.gridCols,
                            cellSize: cellSize, theme: theme)
        gridNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gridNode)

        // Render static obstacles
        for op in def.obstacles {
            let obs = Obstacle(
                id: UUID(),
                position: GridPosition(row: op.row, col: op.col),
                kind: op.kind,
                portalID: op.portalID,
                portalColor: op.portalColor
            )
            gridNode.renderObstacle(obs)
        }
    }

    private func placeAllArrows() {
        for arrow in gameState.allArrows {
            addArrowNode(for: arrow)
        }
    }

    private func addArrowNode(for arrow: Arrow) {
        let node = ArrowNode(arrow: arrow, cellSize: gridNode.cellSize, theme: theme)
        node.position = gridNode.position(for: arrow.position)
        gridNode.addChild(node)
        arrowNodes[arrow.id] = node

        // Entrance animation
        node.alpha = 0
        node.setScale(0.4)
        node.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.25),
            SKAction.scale(to: 1.0, duration: 0.25)
        ]))
    }

    // MARK: - GameState Observation

    private func observeGameState() {
        gameState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)

        gameState.$highlightedArrowID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in self?.updateHighlight(id) }
            .store(in: &cancellables)

        gameState.$wrongTapArrowID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in
                guard let id else { return }
                self?.arrowNodes[id]?.setWrongTap()
                self?.hapticManager.wrongTap()
                self?.audioManager.play(.wrongTap)
            }
            .store(in: &cancellables)
    }

    private func handlePhaseChange(_ phase: GamePhase) {
        switch phase {
        case .levelComplete(let stars):
            triggerWinEffect(stars: stars)
        case .levelFailed:
            triggerFailEffect()
        default: break
        }
    }

    private func updateHighlight(_ id: UUID?) {
        gridNode.clearAllHighlights()
        if let id, let pos = gameState.grid.arrowPositions[id] {
            gridNode.showHighlight(at: pos)
            arrowNodes[id]?.setHighlighted(true)
        }
        // Remove old highlights
        for (aid, node) in arrowNodes {
            if aid != id { node.setHighlighted(false) }
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState.phase == .playing,
              let touch = touches.first else { return }

        let scenePoint = touch.location(in: gridNode)
        guard let gridPos = gridNode.gridPosition(for: scenePoint),
              let arrow = gameState.grid.arrow(at: gridPos) else { return }

        if let path = moveValidator.validateMove(arrow: arrow, in: gameState.grid) {
            triggerSlide(arrow: arrow, path: path)
        } else {
            gameState.handleTap(at: gridPos, moveValidator: moveValidator)
        }
    }

    // MARK: - Slide Animation

    private func triggerSlide(arrow: Arrow, path: SlidePath) {
        guard let node = arrowNodes[arrow.id] else { return }

        hapticManager.arrowTap()
        audioManager.play(.slide)

        // Notify model (updates grid, increments moves, checks win)
        gameState.handleTap(at: arrow.position, moveValidator: moveValidator)

        // Animate
        node.animateSlide(path: path, cellSize: gridNode.cellSize) { [weak self] in
            guard let self else { return }
            node.removeFromParent()
            arrowNodes.removeValue(forKey: arrow.id)
            gameState.finaliseRemoval()
        }
    }

    // MARK: - Win / Fail Effects

    private func triggerWinEffect(stars: Int) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        hapticManager.levelComplete()
        audioManager.play(.success)

        for i in 0..<(stars * 3) {
            let delay = Double(i) * 0.08
            run(SKAction.wait(forDuration: delay)) {
                let offset = CGPoint(
                    x: CGFloat.random(in: -80...80),
                    y: CGFloat.random(in: -60...60)
                )
                ArrowNode.spawnConfetti(
                    in: self,
                    at: CGPoint(x: center.x + offset.x, y: center.y + offset.y)
                )
            }
        }
    }

    private func triggerFailEffect() {
        hapticManager.levelFailed()
        audioManager.play(.failure)
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -12, y: 0, duration: 0.06),
            SKAction.moveBy(x: 24, y: 0, duration: 0.06),
            SKAction.moveBy(x: -24, y: 0, duration: 0.06),
            SKAction.moveBy(x: 12, y: 0, duration: 0.06)
        ])
        gridNode.run(shake)
    }

    // MARK: - Rebuild (Restart)

    func rebuild() {
        arrowNodes.values.forEach { $0.removeFromParent() }
        arrowNodes.removeAll()
        gridNode.clearAllHighlights()
        placeAllArrows()
    }
}
