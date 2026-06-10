// ArrowNode.swift
// ZenithArrows
// SpriteKit node representing one arrow on the game board.
// Handles all visual states: idle, highlighted (hint), wrong-tap, and slide-out animation.

import SpriteKit
import SwiftUI

final class ArrowNode: SKNode {

    // MARK: - Properties
    let arrowID: UUID
    private let direction: ArrowDirection
    private let arrowType: ArrowType
    private let arrowColor: ArrowColor

    // Visual layers
    private let bodyNode: SKShapeNode
    private let glowNode: SKEffectNode
    private var particleEmitter: SKEmitterNode?
    private var isAnimating = false

    // Callbacks
    var onSlideComplete: (() -> Void)?

    // MARK: - Init

    init(arrow: Arrow, cellSize: CGFloat, theme: GameTheme) {
        self.arrowID = arrow.id
        self.direction = arrow.direction
        self.arrowType = arrow.type
        self.arrowColor = arrow.color

        // --- Body ---
        let size = cellSize * 0.72
        let path = ArrowNode.arrowPath(size: size)
        bodyNode = SKShapeNode(path: path)
        bodyNode.fillColor = theme.arrowFillColor(for: arrow.color)
        bodyNode.strokeColor = theme.arrowStrokeColor(for: arrow.color)
        bodyNode.lineWidth = 2
        bodyNode.zRotation = CGFloat(arrow.direction.rotationDegrees) * .pi / 180

        // --- Glow (subtle drop-shadow via blur filter) ---
        glowNode = SKEffectNode()
        glowNode.shouldEnableEffects = true
        glowNode.filter = CIFilter(name: "CIGaussianBlur",
                                   parameters: ["inputRadius": 8])

        let glowCopy = SKShapeNode(path: path)
        glowCopy.fillColor = bodyNode.fillColor.withAlphaComponent(0.5)
        glowCopy.strokeColor = .clear
        glowCopy.zRotation = bodyNode.zRotation
        glowNode.addChild(glowCopy)
        glowNode.alpha = 0.6

        super.init()

        addChild(glowNode)
        addChild(bodyNode)

        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("not implemented") }

    // MARK: - Arrow Path (chevron / arrowhead shape)

    private static func arrowPath(size: CGFloat) -> CGPath {
        let h = size
        let w = size * 0.6
        let shaftW = w * 0.35
        let headH = h * 0.45

        let path = CGMutablePath()
        // Tip pointing UP
        path.move(to: CGPoint(x: 0, y: h / 2))
        path.addLine(to: CGPoint(x:  w / 2, y: h / 2 - headH))
        path.addLine(to: CGPoint(x:  shaftW / 2, y: h / 2 - headH))
        path.addLine(to: CGPoint(x:  shaftW / 2, y: -h / 2))
        path.addLine(to: CGPoint(x: -shaftW / 2, y: -h / 2))
        path.addLine(to: CGPoint(x: -shaftW / 2, y: h / 2 - headH))
        path.addLine(to: CGPoint(x: -w / 2, y: h / 2 - headH))
        path.closeSubpath()
        return path
    }

    // MARK: - Visual State Updates

    func setHighlighted(_ highlighted: Bool) {
        let scaleTarget: CGFloat = highlighted ? 1.12 : 1.0
        bodyNode.removeAction(forKey: "pulse")
        bodyNode.removeAction(forKey: "moveablePulse")
        bodyNode.run(SKAction.scale(to: scaleTarget, duration: 0.15))
        glowNode.run(SKAction.fadeAlpha(to: highlighted ? 1.0 : 0.6, duration: 0.15))
        if highlighted {
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.4),
                SKAction.fadeAlpha(to: 1.0, duration: 0.4)
            ]))
            bodyNode.run(pulse, withKey: "pulse")
        }
    }

    /// Brief moveable-arrow ping: tiny scale-up then back, repeated a few times
    func pulseMoveable(briefly: Bool) {
        bodyNode.removeAction(forKey: "moveablePulse")
        let ping = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.18),
            SKAction.scale(to: 1.00, duration: 0.18)
        ])
        let action: SKAction = briefly
            ? SKAction.sequence([ping, ping, ping])
            : SKAction.repeatForever(ping)
        bodyNode.run(action, withKey: "moveablePulse")
    }

    func stopMoveablePulse() {
        bodyNode.removeAction(forKey: "moveablePulse")
        bodyNode.run(SKAction.scale(to: 1.0, duration: 0.1))
    }

    func setWrongTap() {
        guard !isAnimating else { return }
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -6, y: 0, duration: 0.05),
            SKAction.moveBy(x: 12, y: 0, duration: 0.05),
            SKAction.moveBy(x: -12, y: 0, duration: 0.05),
            SKAction.moveBy(x: 6, y: 0, duration: 0.05)
        ])
        let redFlash = SKAction.sequence([
            SKAction.colorize(with: .systemRed, colorBlendFactor: 0.8, duration: 0.1),
            SKAction.colorize(with: .clear, colorBlendFactor: 0.0, duration: 0.2)
        ])
        bodyNode.run(redFlash)
        run(shake)
    }

    // MARK: - Slide-Out Animation

    /// Animates the arrow sliding in its pointed direction, leaving a particle trail.
    /// - Parameters:
    ///   - path: The SlidePath for this move.
    ///   - cellSize: Size of a single grid cell in points.
    ///   - completion: Called when animation finishes (node can then be removed).
    func animateSlide(path: SlidePath, cellSize: CGFloat, completion: @escaping () -> Void) {
        guard !isAnimating else { return }
        isAnimating = true

        attachParticleTrail()

        // Calculate final offscreen position
        let dx: CGFloat
        let dy: CGFloat
        let totalCells = path.cells.count + 1  // +1 to fully exit

        switch direction {
        case .up:        dx = 0;                dy =  CGFloat(totalCells) * cellSize
        case .down:      dx = 0;                dy = -CGFloat(totalCells) * cellSize
        case .left:      dx = -CGFloat(totalCells) * cellSize; dy = 0
        case .right:     dx =  CGFloat(totalCells) * cellSize; dy = 0
        case .upLeft:    dx = -CGFloat(totalCells) * cellSize * 0.707
                         dy =  CGFloat(totalCells) * cellSize * 0.707
        case .upRight:   dx =  CGFloat(totalCells) * cellSize * 0.707
                         dy =  CGFloat(totalCells) * cellSize * 0.707
        case .downLeft:  dx = -CGFloat(totalCells) * cellSize * 0.707
                         dy = -CGFloat(totalCells) * cellSize * 0.707
        case .downRight: dx =  CGFloat(totalCells) * cellSize * 0.707
                         dy = -CGFloat(totalCells) * cellSize * 0.707
        }

        let slideDuration: TimeInterval = arrowType == .ice ? 0.18 : 0.28

        let slideAction = SKAction.moveBy(x: dx, y: dy, duration: slideDuration)
        slideAction.timingMode = .easeIn

        let fadeAction = SKAction.sequence([
            SKAction.wait(forDuration: slideDuration * 0.75),
            SKAction.fadeOut(withDuration: slideDuration * 0.25)
        ])

        run(SKAction.group([slideAction, fadeAction])) { [weak self] in
            self?.particleEmitter?.particleBirthRate = 0
            completion()
        }
    }

    // MARK: - Particle Trail

    private func attachParticleTrail() {
        guard let emitter = SKEmitterNode(fileNamed: "ArrowTrail.sks") else {
            // Fallback: programmatic particle if .sks not found
            let emitter = buildFallbackEmitter()
            addChild(emitter)
            self.particleEmitter = emitter
            return
        }
        emitter.targetNode = parent
        addChild(emitter)
        particleEmitter = emitter
    }

    private func buildFallbackEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 60
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 20
        emitter.emissionAngle = .pi // emit backwards
        emitter.emissionAngleRange = 0.3
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -2.0
        emitter.particleScale = 0.15
        emitter.particleScaleSpeed = -0.3
        emitter.particleColor = bodyNode.fillColor
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }

    // MARK: - Win Celebration (confetti burst)

    static func spawnConfetti(in scene: SKScene, at position: CGPoint) {
        let colors: [SKColor] = [.systemYellow, .systemPink, .systemCyan,
                                 .systemGreen, .systemOrange, .white]
        for i in 0..<24 {
            let confetti = SKShapeNode(rectOf: CGSize(width: 8, height: 5),
                                       cornerRadius: 1)
            confetti.fillColor = colors[i % colors.count]
            confetti.strokeColor = .clear
            confetti.position = position
            scene.addChild(confetti)

            let angle = CGFloat(i) / 24 * .pi * 2
            let dist: CGFloat = .random(in: 80...200)
            let endPos = CGPoint(
                x: position.x + cos(angle) * dist,
                y: position.y + sin(angle) * dist
            )
            let move = SKAction.move(to: endPos, duration: 0.6)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.4)
            let rotate = SKAction.rotate(byAngle: .random(in: -4 ... 4), duration: 0.6)
            confetti.run(SKAction.group([move, fade, rotate])) {
                confetti.removeFromParent()
            }
        }
    }
}
