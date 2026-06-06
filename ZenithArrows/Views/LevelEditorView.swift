// LevelEditorView.swift
// ZenithArrows
// In-app level editor for designers and testing.
// Export produces a LevelDefinition JSON string ready to paste into a world file.

import SwiftUI

@MainActor
final class LevelEditorState: ObservableObject {

    @Published var rows: Int = 5
    @Published var cols: Int = 5
    @Published var placements: [ArrowPlacement] = []
    @Published var obstacles: [ObstaclePlacement] = []
    @Published var selectedTool: EditorTool = .arrow(.up)
    @Published var difficulty: LevelDifficulty = .easy
    @Published var parMoves: Int = 10
    @Published var levelTitle: String = "My Level"
    @Published var exportedJSON: String = ""
    @Published var validationResult: String = ""

    enum EditorTool: Hashable {
        case arrow(ArrowDirection)
        case obstacle(Obstacle.ObstacleKind)
        case eraser
    }

    func tap(row: Int, col: Int) {
        switch selectedTool {
        case .arrow(let dir):
            placements.removeAll { $0.row == row && $0.col == col }
            obstacles.removeAll { $0.row == row && $0.col == col }
            placements.append(ArrowPlacement(row: row, col: col, direction: dir))
        case .obstacle(let kind):
            placements.removeAll { $0.row == row && $0.col == col }
            obstacles.removeAll { $0.row == row && $0.col == col }
            obstacles.append(ObstaclePlacement(row: row, col: col, kind: kind))
        case .eraser:
            placements.removeAll { $0.row == row && $0.col == col }
            obstacles.removeAll { $0.row == row && $0.col == col }
        }
    }

    func validate() {
        let grid = GridModel(rows: rows, cols: cols)
        for ap in placements {
            let arrow = Arrow(direction: ap.direction,
                              position: GridPosition(row: ap.row, col: ap.col))
            grid.place(arrow: arrow)
        }
        let hint = HintEngine()
        if hint.isSolvable(grid: grid) {
            validationResult = "✅ Level is solvable in \(placements.count) moves."
        } else {
            validationResult = "❌ Level has no solution — adjust arrow placements."
        }
    }

    func exportJSON(worldID: Int = 99, index: Int = 1) {
        let arrowsJSON = placements.map {
            "{\"row\":\($0.row),\"col\":\($0.col),\"direction\":\"\($0.direction.rawValue)\"}"
        }.joined(separator: ",")

        let obstaclesJSON = obstacles.map {
            "{\"row\":\($0.row),\"col\":\($0.col),\"kind\":\"\($0.kind.rawValue)\"}"
        }.joined(separator: ",")

        exportedJSON = """
        {
          "id": "custom_\(Int(Date().timeIntervalSince1970))",
          "worldID": \(worldID),
          "index": \(index),
          "gridRows": \(rows),
          "gridCols": \(cols),
          "arrows": [\(arrowsJSON)],
          "obstacles": [\(obstaclesJSON)],
          "difficulty": "\(difficulty.rawValue)",
          "parMoves": \(parMoves),
          "parTime": \(Double(parMoves) * 5.0),
          "diagonalsEnabled": false,
          "title": "\(levelTitle)"
        }
        """
    }
}

struct LevelEditorView: View {

    @StateObject private var editor = LevelEditorState()
    @StateObject private var theme = ThemeManager.shared
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 12) {
                    // MARK: Tool Picker
                    toolPicker

                    // MARK: Grid
                    editorGrid

                    // MARK: Actions
                    HStack(spacing: 12) {
                        EditorActionButton(title: "Validate", systemImage: "checkmark.shield") {
                            editor.validate()
                        }
                        EditorActionButton(title: "Export JSON", systemImage: "square.and.arrow.up") {
                            editor.exportJSON()
                            showExport = true
                        }
                        EditorActionButton(title: "Clear", systemImage: "trash") {
                            editor.placements.removeAll()
                            editor.obstacles.removeAll()
                        }
                    }
                    .padding(.horizontal, 16)

                    if !editor.validationResult.isEmpty {
                        Text(editor.validationResult)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(theme.current.textColor)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle("Level Editor")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(json: editor.exportedJSON)
        }
    }

    // MARK: - Tool Picker

    private var toolPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Arrow tools
                ForEach(ArrowDirection.cardinalDirections, id: \.self) { dir in
                    ToolButton(label: dir.rawValue.prefix(1).uppercased(),
                                isSelected: editor.selectedTool == .arrow(dir)) {
                        editor.selectedTool = .arrow(dir)
                    }
                }
                Divider().frame(height: 30)
                // Obstacle tools
                ToolButton(label: "■", isSelected: editor.selectedTool == .obstacle(.wall)) {
                    editor.selectedTool = .obstacle(.wall)
                }
                ToolButton(label: "❄", isSelected: editor.selectedTool == .obstacle(.ice)) {
                    editor.selectedTool = .obstacle(.ice)
                }
                ToolButton(label: "⚡", isSelected: editor.selectedTool == .obstacle(.trap)) {
                    editor.selectedTool = .obstacle(.trap)
                }
                Divider().frame(height: 30)
                ToolButton(label: "✕", isSelected: editor.selectedTool == .eraser) {
                    editor.selectedTool = .eraser
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Editor Grid

    private var editorGrid: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height) / CGFloat(max(editor.rows, editor.cols))
            VStack(spacing: 1) {
                ForEach(0..<editor.rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<editor.cols, id: \.self) { col in
                            EditorCell(
                                row: row, col: col,
                                placements: editor.placements,
                                obstacles: editor.obstacles,
                                cellSize: cellSize
                            )
                            .onTapGesture { editor.tap(row: row, col: col) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(CGFloat(editor.cols) / CGFloat(editor.rows), contentMode: .fit)
        .padding(.horizontal, 16)
    }
}

// MARK: - Sub-components

struct ToolButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .black : theme.current.textColor)
                .frame(width: 36, height: 36)
                .background(isSelected ? theme.current.accentColor : theme.current.buttonBackground,
                             in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct EditorCell: View {
    let row: Int
    let col: Int
    let placements: [ArrowPlacement]
    let obstacles: [ObstaclePlacement]
    let cellSize: CGFloat
    @StateObject private var theme = ThemeManager.shared

    private var arrow: ArrowPlacement? {
        placements.first { $0.row == row && $0.col == col }
    }
    private var obstacle: ObstaclePlacement? {
        obstacles.first { $0.row == row && $0.col == col }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(theme.current.cellBackground))
                .frame(width: cellSize - 2, height: cellSize - 2)

            if let a = arrow {
                Image(systemName: a.direction.systemImageName)
                    .font(.system(size: cellSize * 0.42, weight: .bold))
                    .foregroundStyle(theme.current.accentColor)
                    .rotationEffect(.degrees(0)) // direction already in symbol
            } else if let o = obstacle {
                Text(obstacleSymbol(o.kind))
                    .font(.system(size: cellSize * 0.38))
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func obstacleSymbol(_ kind: Obstacle.ObstacleKind) -> String {
        switch kind {
        case .wall: return "■"
        case .ice:  return "❄"
        case .trap: return "⚡"
        case .portal: return "○"
        }
    }
}

struct EditorActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.textColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.current.buttonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(16)
                    .textSelection(.enabled)
            }
            .navigationTitle("Exported JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: json)
                }
            }
        }
    }
}
