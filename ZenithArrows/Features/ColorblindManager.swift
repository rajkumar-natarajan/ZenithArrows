// ColorblindManager.swift
// ZenithArrows
//
// Feature 18: Colorblind Mode.
//
// Adds optional shape/label overlays to arrow cells so that portal
// matching does not rely on colour perception alone.
//
// ## Overlay Modes
//
// | Mode     | Overlay Content                          |
// |----------|------------------------------------------|
// | shapes   | SF Symbol icon (triangle, square, etc.)  |
// | labels   | Single capital letter (R, B, G, Y, P, O) |
// | both     | Icon + letter stacked                    |
//
// ## Shape Mapping
//
// | ArrowColor | Shape    | Label |
// |------------|----------|-------|
// | white      | circle   | —     |
// | red        | triangle | R     |
// | blue       | square   | B     |
// | green      | diamond  | G     |
// | yellow     | star     | Y     |
// | purple     | pentagon | P     |
// | orange     | cross    | O     |
//
// ## Integration
//
// `ColorblindManager.shared.overlay(for:cellSize:)` returns a SwiftUI view
// with `allowsHitTesting(false)` to overlay on ArrowNode cells.
// Toggled in `SettingsView`; persisted in `zenith_colorblind_v1`.

import SwiftUI
import SpriteKit

// MARK: - Colorblind Shape

enum ColorblindShape: String, CaseIterable {
    case circle    = "circle.fill"
    case square    = "square.fill"
    case triangle  = "triangle.fill"
    case diamond   = "diamond.fill"
    case star      = "star.fill"
    case pentagon  = "pentagon.fill"
    case cross     = "plus.circle.fill"

    /// One shape per ArrowColor (excluding .white which needs no overlay)
    static func shape(for color: ArrowColor) -> ColorblindShape {
        switch color {
        case .white:  return .circle
        case .red:    return .triangle
        case .blue:   return .square
        case .green:  return .diamond
        case .yellow: return .star
        case .purple: return .pentagon
        case .orange: return .cross
        }
    }

    /// Short letter label alternative
    static func label(for color: ArrowColor) -> String {
        switch color {
        case .white:  return ""
        case .red:    return "R"
        case .blue:   return "B"
        case .green:  return "G"
        case .yellow: return "Y"
        case .purple: return "P"
        case .orange: return "O"
        }
    }
}

// MARK: - ColorblindManager

@MainActor
final class ColorblindManager: ObservableObject {

    static let shared = ColorblindManager()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: storageKey)
        }
    }

    @Published var mode: ColorblindMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        }
    }

    private let storageKey = "zenith_colorblind_v1"
    private let modeKey    = "zenith_colorblind_mode_v1"

    enum ColorblindMode: String, CaseIterable {
        case shapes = "shapes"   // geometric shape overlay
        case labels = "labels"   // letter label overlay
        case both   = "both"     // shapes + letters
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "zenith_colorblind_v1")
        let saved = UserDefaults.standard.string(forKey: "zenith_colorblind_mode_v1") ?? "shapes"
        mode = ColorblindMode(rawValue: saved) ?? .shapes
    }

    // MARK: - Overlay View

    /// Returns an AnyView overlay to place atop an arrow cell.
    func overlay(for color: ArrowColor, cellSize: CGFloat) -> some View {
        Group {
            if isEnabled && color != .white {
                ColorblindOverlayView(
                    color: color,
                    mode: mode,
                    cellSize: cellSize
                )
            }
        }
    }
}

// MARK: - Overlay View

struct ColorblindOverlayView: View {
    let color: ArrowColor
    let mode: ColorblindManager.ColorblindMode
    let cellSize: CGFloat

    private var shape: ColorblindShape { ColorblindShape.shape(for: color) }
    private var label: String { ColorblindShape.label(for: color) }
    private var badgeSize: CGFloat { cellSize * 0.28 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            VStack(spacing: 1) {
                if mode == .shapes || mode == .both {
                    Image(systemName: shape.rawValue)
                        .font(.system(size: badgeSize * 0.7))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                }
                if mode == .labels || mode == .both {
                    Text(label)
                        .font(.system(size: badgeSize * 0.65, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                }
            }
            .padding(3)
        }
        .frame(width: cellSize, height: cellSize)
        .allowsHitTesting(false)
    }
}
