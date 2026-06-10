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
    /// Set of arrow IDs currently mid-animation — blocks taps on those arrows
    private var slidingArrowIDs: Set<UUID> = []

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        setupGrid()
        placeAllArrows(animated: true)
        observeGameState()
    }

    // MARK: - Setup

    private var cellSize: CGFloat {
        gridNode?.cellSize ?? 60
    }

    private func setupGrid() {
        guard gameState != nil else { return }
        let def = gameState.levelDefinition
        let maxDim = max(def.gridRows, def.gridCols)
        let availableSize = min(size.width, size.height) * 0.90
        let cs = floor(availableSize / CGFloat(maxDim))

        gridNode = GridNode(rows: def.gridRows, cols: def.gridCols,
                            cellSize: cs, theme: theme)
        gridNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gridNode)

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

    private func placeAllArrows(animated: Bool) {
        guard gameState != nil else { return }
        for (i, arrow) in gameState.allArrows.enumerated() {
            addArrowNode(for: arrow, entranceDelay: animated ? Double(i) * 0.035 : 0)
        }
        if animated {
            // After all arrows appear, highlight moveable ones briefly
            let totalEntrance = Double(gameState.allArrows.count) * 0.035 + 0.3
            run(SKAction.wait(forDuration: totalEntrance)) { [weak self] in
                self?.highlightMoveableArrows(briefly: true)
            }
        }
    }

    private func addArrowNode(for arrow: Arrow, entranceDelay: Double = 0) {
        guard gridNode != nil else { return }
        let node = ArrowNode(arrow: arrow, cellSize: gridNode.cellSize, theme: theme)
        node.position = gridNode.position(for: arrow.position)
        node.alpha = 0
        node.setScale(0.3)
        gridNode.addChild(node)
        arrowNodes[arrow.id] = node

        let appear = SKAction.group([
            SKAction.fadeIn(withDuration: 0.22),
            SKAction.scale(to: 1.0, duration: 0.22)
        ])
        appear.timingMode = .easeOut
        node.run(SKAction.sequence([
            SKAction.wait(forDuration: entranceDelay),
            appear
        ]))
    }

    /// Briefly pulses all currently-moveable arrows so the player knows where to start.
    private func highlightMoveableArrows(briefly: Bool) {
        guard gameState != nil else { return }
        let moveable = moveValidator.moveableArrows(in: gameState.grid)
        for arrow in moveable {
            arrowNodes[arrow.id]?.pulseMoveable(briefly: briefly)
        }
    }

    // MARK: - GameState Observation

    private func observeGameState() {
        guard gameState != nil else { return }

        gameState.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.handlePhaseChange(phase) }
            .store(in: &cancellables)

        gameState.$highlightedArrowID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in self?.updateHintHighlight(id) }
            .store(in: &cancellables)

        gameState.$wrongTapArrowID
            .receive(on: RunLoop.main)
            .sink { [weak self] id in
                guard let self, let id else { return }
                arrowNodes[id]?.setWrongTap()
                hapticManager.wrongTap()
                audioManager.play(.wrongTap)
            }
            .store(in: &cancellables)
    }

    private func handlePhaseChange(_ phase: GamePhase) {
        switch phase {
        case .levelComplete(let stars):
            triggerWinEffect(stars: stars)
        case .levelFailed:
            triggerFailEffect()
        case .playing:
            // After undo: refresh moveable highlights
            highlightMoveableArrows(briefly: false)
        default:
            break
        }
    }

    private func updateHintHighlight(_ id: UUID?) {
        gridNode?.clearAllHighlights()
        for (aid, node) in arrowNodes {
            node.setHighlighted(aid == id)
        }
        if let id, let pos = gameState?.grid.arrowPositions[id] {
            gridNode?.showHighlight(at: pos, color: .systemYellow)
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let scenePoint = touch.location(in: gridNode)
        guard let gridPos = gridNode?.gridPosition(for: scenePoint) else { return }

        // Dispatch to main actor for gameState access
        Task { @MainActor [weak self] in
            guard let self, let gs = self.gameState,
                  gs.phase == .playing else { return }
            guard let arrow = gs.grid.arrow(at: gridPos),
                  !self.slidingArrowIDs.contains(arrow.id) else { return }

            if let path = self.moveValidator.validateMove(arrow: arrow, in: gs.grid) {
                self.triggerSlide(arrow: arrow, path: path)
            } else {
                gs.handleTap(at: gridPos, moveValidator: self.moveValidator)
            }
        }
    }

    // MARK: - Slide Animation

    private func triggerSlide(arrow: Arrow, path: SlidePath) {
        guard let node = arrowNodes[arrow.id],
              !slidingArrowIDs.contains(arrow.id) else { return }

        slidingArrowIDs.insert(arrow.id)
        hapticManager.arrowTap()
        audioManager.play(.slide)

        // Commit to model FIRST
        gameState.handleTap(at: arrow.position, moveValidator: moveValidator)

        // Animate the node
        node.animateSlide(path: path, cellSize: gridNode.cellSize) { [weak self] in
            guard let self else { return }
            self.slidingArrowIDs.remove(arrow.id)
            node.removeFromParent()
            self.arrowNodes.removeValue(forKey: arrow.id)

            Task { @MainActor [weak self] in
                self?.gameState?.finaliseRemoval(arrowID: arrow.id)
                // After each successful removal, refresh moveable hints
                self?.highlightMoveableArrows(briefly: false)
            }
        }
    }

    // MARK: - Win / Fail Effects

    private func triggerWinEffect(stars: Int) {
        hapticManager.levelComplete()
        audioManager.play(.success)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let burstCount = 6 + stars * 4
        for i in 0..<burstCount {
            let delay = Double(i) * 0.06
            run(SKAction.wait(forDuration: delay)) { [weak self] in
                guard let self else { return }
                let randomOffset = CGPoint(
                    x: CGFloat.random(in: -100...100),
                    y: CGFloat.random(in: -80...80)
                )
                ArrowNode.spawnConfetti(
                    in: self,
                    at: CGPoint(x: center.x + randomOffset.x,
                                y: center.y + randomOffset.y)
                )
            }
        }
    }

    private func triggerFailEffect() {
        hapticManager.levelFailed()
        audioManager.play(.failure)
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -14, y: 0, duration: 0.05),
            SKAction.moveBy(x: 28, y: 0, duration: 0.05),
            SKAction.moveBy(x: -28, y: 0, duration: 0.05),
            SKAction.moveBy(x: 14, y: 0, duration: 0.05)
        ])
        gridNode?.run(shake)
    }

    // MARK: - Rebuild (after undo or restart)

    func rebuild() {
        // Remove all existing arrow nodes
        arrowNodes.values.forEach { $0.removeFromParent() }
        arrowNodes.removeAll()
        slidingArrowIDs.removeAll()
        gridNode?.clearAllHighlights()
        placeAllArrows(animated: false)
        // Show moveable hints immediately after rebuild
        highlightMoveableArrows(briefly: false)
    }
}
