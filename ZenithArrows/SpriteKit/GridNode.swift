// GridNode.swift
// ZenithArrows
// SpriteKit node that draws the background grid lines and cell highlight overlays.

import SpriteKit

final class GridNode: SKNode {

    let rows: Int
    let cols: Int
    let cellSize: CGFloat
    let theme: GameTheme

    // Highlight overlays keyed by grid position
    private var highlightNodes: [GridPosition: SKShapeNode] = [:]

    init(rows: Int, cols: Int, cellSize: CGFloat, theme: GameTheme) {
        self.rows = rows
        self.cols = cols
        self.cellSize = cellSize
        self.theme = theme
        super.init()
        buildGrid()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Grid Drawing

    private func buildGrid() {
        let totalW = CGFloat(cols) * cellSize
        let totalH = CGFloat(rows) * cellSize

        // Background panel
        let bg = SKShapeNode(rectOf: CGSize(width: totalW + 4, height: totalH + 4),
                              cornerRadius: 12)
        bg.fillColor = theme.gridBackground
        bg.strokeColor = theme.gridBorder
        bg.lineWidth = 2
        addChild(bg)

        // Cell borders
        for row in 0..<rows {
            for col in 0..<cols {
                let cell = SKShapeNode(rectOf: CGSize(width: cellSize - 1,
                                                      height: cellSize - 1),
                                       cornerRadius: 4)
                cell.fillColor = theme.cellBackground
                cell.strokeColor = theme.gridBorder.withAlphaComponent(0.3)
                cell.lineWidth = 0.5
                cell.position = position(for: GridPosition(row: row, col: col))
                addChild(cell)
            }
        }
    }

    // MARK: - Coordinate Conversion

    /// Converts grid position to SpriteKit scene coordinates (centered in the cell).
    func position(for gridPos: GridPosition) -> CGPoint {
        let totalH = CGFloat(rows) * cellSize
        let totalW = CGFloat(cols) * cellSize
        let x = CGFloat(gridPos.col) * cellSize - totalW / 2 + cellSize / 2
        let y = totalH / 2 - CGFloat(gridPos.row) * cellSize - cellSize / 2
        return CGPoint(x: x, y: y)
    }

    /// Converts scene point to grid position (returns nil if outside grid).
    func gridPosition(for scenePoint: CGPoint) -> GridPosition? {
        let totalW = CGFloat(cols) * cellSize
        let totalH = CGFloat(rows) * cellSize
        let localX = scenePoint.x + totalW / 2
        let localY = totalH / 2 - scenePoint.y

        let col = Int(localX / cellSize)
        let row = Int(localY / cellSize)

        guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
        return GridPosition(row: row, col: col)
    }

    // MARK: - Cell Highlights (for hint / tutorial)

    func showHighlight(at pos: GridPosition, color: SKColor = .systemYellow) {
        removeHighlight(at: pos)
        let node = SKShapeNode(rectOf: CGSize(width: cellSize - 4,
                                              height: cellSize - 4),
                               cornerRadius: 6)
        node.fillColor = color.withAlphaComponent(0.25)
        node.strokeColor = color
        node.lineWidth = 2
        node.position = position(for: pos)
        node.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.15, duration: 0.5),
                SKAction.fadeAlpha(to: 0.4, duration: 0.5)
            ])
        ))
        addChild(node)
        highlightNodes[pos] = node
    }

    func removeHighlight(at pos: GridPosition) {
        highlightNodes[pos]?.removeFromParent()
        highlightNodes.removeValue(forKey: pos)
    }

    func clearAllHighlights() {
        highlightNodes.values.forEach { $0.removeFromParent() }
        highlightNodes.removeAll()
    }

    // MARK: - Obstacle Rendering

    func renderObstacle(_ obs: Obstacle) {
        let pos = position(for: obs.position)
        switch obs.kind {
        case .wall:
            let block = SKShapeNode(rectOf: CGSize(width: cellSize - 2,
                                                    height: cellSize - 2),
                                    cornerRadius: 4)
            block.fillColor = theme.obstacleColor
            block.strokeColor = theme.gridBorder
            block.position = pos
            addChild(block)

        case .portal:
            let circle = SKShapeNode(circleOfRadius: cellSize * 0.38)
            circle.fillColor = (obs.portalColor.map { theme.arrowFillColor(for: $0) }) ?? .purple
            circle.strokeColor = .white
            circle.lineWidth = 2
            circle.position = pos
            let pulse = SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 0.9, duration: 0.5)
            ]))
            circle.run(pulse)
            addChild(circle)

        case .ice:
            let ice = SKShapeNode(rectOf: CGSize(width: cellSize - 4,
                                                  height: cellSize - 4),
                                  cornerRadius: 4)
            ice.fillColor = SKColor.systemCyan.withAlphaComponent(0.35)
            ice.strokeColor = .systemCyan
            ice.lineWidth = 1
            ice.position = pos
            addChild(ice)

        case .trap:
            let trap = SKShapeNode(rectOf: CGSize(width: cellSize - 4,
                                                   height: cellSize - 4),
                                   cornerRadius: 4)
            trap.fillColor = SKColor.systemRed.withAlphaComponent(0.3)
            trap.strokeColor = .systemOrange
            trap.lineWidth = 1
            trap.position = pos
            addChild(trap)
        }
    }
}
