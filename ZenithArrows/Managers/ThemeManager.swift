// ThemeManager.swift
// ZenithArrows
//
// Defines visual themes and vends the active theme to all rendering layers.
//
// ## Themes
//
// | Key      | Name         | Unlock Condition          |
// |----------|--------------|---------------------------|
// | zen      | Zen Stone    | Always free (default)     |
// | neon     | Neon City    | 100 stars OR 14-day streak|
// | cyber    | Cyber        | 300 stars OR 30-day streak|
// | nature   | Nature       | 50 stars                  |
// | dark     | Pure Dark    | 100-day streak only       |
//
// ## Feature 13 — Theme Unlocking
//
// `unlockTheme(key:)` — grants access and persists via `zenith_unlocked_themes_v1`.
// `checkStarUnlocks(totalStars:)` — called after level completion to auto-unlock
//   star-gated themes.
// `select(themeKey:)` — no-ops if the key is not in `unlockedThemeKeys`.
// `displayThemes` — returns `(theme, isUnlocked, requiredStars?)` for Settings UI.
//
// ## `GameTheme` Struct
//
// Contains SpriteKit (`SKColor`) and SwiftUI (`Color`, `LinearGradient`) colour
// definitions for every UI element so both layers always stay in sync.

import SwiftUI
import SpriteKit

// MARK: - Game Theme Protocol

struct GameTheme {
    let name: String
    let key: String

    // Grid
    let gridBackground: SKColor
    let gridBorder: SKColor
    let cellBackground: SKColor
    let obstacleColor: SKColor

    // Arrows
    let arrowFillColors: [ArrowColor: SKColor]
    let arrowStrokeColors: [ArrowColor: SKColor]

    // SwiftUI
    let backgroundGradient: LinearGradient
    let accentColor: Color
    let textColor: Color
    let hudBackground: Color
    let buttonBackground: Color

    func arrowFillColor(for color: ArrowColor) -> SKColor {
        arrowFillColors[color] ?? .white
    }
    func arrowStrokeColor(for color: ArrowColor) -> SKColor {
        arrowStrokeColors[color] ?? .lightGray
    }
}

// MARK: - ThemeManager

@MainActor
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    @Published private(set) var current: GameTheme
    @Published private(set) var availableThemes: [GameTheme]
    @Published private(set) var unlockedThemeKeys: Set<String>

    private let defaultKey   = "zenith_theme_v1"
    private let unlockedKey  = "zenith_unlocked_themes_v1"

    // Themes that require a star milestone to unlock (Feature 13)
    static let lockedThemeKeys: [String: Int] = [
        "neon":   14,   // unlock via 14-day streak reward
        "cyber":  30,   // unlock via 30-day streak reward
        "dark":   100,  // unlock via 100-day streak reward
        "nature": 50    // unlock by earning 50 total stars
    ]
    // "zen" is always free

    private init() {
        let all = ThemeManager.buildThemes()
        availableThemes = all

        // Load persisted unlocked set (zen is always unlocked)
        var savedUnlocked: Set<String>
        if let data = UserDefaults.standard.data(forKey: "zenith_unlocked_themes_v1"),
           let keys = try? JSONDecoder().decode([String].self, from: data) {
            savedUnlocked = Set(keys)
        } else {
            savedUnlocked = ["zen"]
        }
        savedUnlocked.insert("zen")
        unlockedThemeKeys = savedUnlocked

        let savedKey = UserDefaults.standard.string(forKey: "zenith_theme_v1") ?? "zen"
        // Fall back to "zen" if saved theme is not yet unlocked
        let resolvedKey = savedUnlocked.contains(savedKey) ? savedKey : "zen"
        current = all.first { $0.key == resolvedKey } ?? all[0]
    }

    func select(themeKey: String) {
        guard let theme = availableThemes.first(where: { $0.key == themeKey }),
              isUnlocked(themeKey: themeKey) else { return }
        current = theme
        UserDefaults.standard.set(themeKey, forKey: defaultKey)
    }

    // Feature 13 – unlock a theme programmatically (called by StreakRewardManager)
    func unlockTheme(key: String) {
        unlockedThemeKeys.insert(key)
        persistUnlocked()
    }

    // Feature 13 – unlock themes via star count
    func checkStarUnlocks(totalStars: Int) {
        if totalStars >= 50 { unlockTheme(key: "nature") }
        if totalStars >= 100 { unlockTheme(key: "neon") }
        if totalStars >= 300 { unlockTheme(key: "cyber") }
    }

    func isUnlocked(themeKey: String) -> Bool {
        unlockedThemeKeys.contains(themeKey)
    }

    var lockedThemes: [GameTheme] {
        availableThemes.filter { !isUnlocked(themeKey: $0.key) }
    }

    var displayThemes: [(theme: GameTheme, isUnlocked: Bool, requiredStars: Int?)] {
        availableThemes.map { t in
            (t, isUnlocked(themeKey: t.key), ThemeManager.lockedThemeKeys[t.key])
        }
    }

    private func persistUnlocked() {
        let keys = Array(unlockedThemeKeys)
        if let data = try? JSONEncoder().encode(keys) {
            UserDefaults.standard.set(data, forKey: unlockedKey)
        }
    }

    // MARK: - Theme Definitions

    private static func buildThemes() -> [GameTheme] {
        [zenTheme, neonTheme, cyberTheme, natureTheme, darkTheme]
    }

    // MARK: Zen Stone (default)
    static let zenTheme = GameTheme(
        name: "Zen Stone", key: "zen",
        gridBackground: SKColor(white: 0.14, alpha: 1),
        gridBorder: SKColor(white: 0.28, alpha: 1),
        cellBackground: SKColor(white: 0.17, alpha: 1),
        obstacleColor: SKColor(white: 0.35, alpha: 1),
        arrowFillColors: [
            .white:  SKColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
            .red:    SKColor(red: 0.90, green: 0.25, blue: 0.25, alpha: 1),
            .blue:   SKColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1),
            .green:  SKColor(red: 0.25, green: 0.82, blue: 0.45, alpha: 1),
            .yellow: SKColor(red: 0.98, green: 0.82, blue: 0.15, alpha: 1),
            .purple: SKColor(red: 0.72, green: 0.30, blue: 0.92, alpha: 1),
            .orange: SKColor(red: 0.98, green: 0.55, blue: 0.15, alpha: 1)
        ],
        arrowStrokeColors: [
            .white: SKColor(white: 0.7, alpha: 1),
            .red: SKColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1),
            .blue: SKColor(red: 0.1, green: 0.35, blue: 0.75, alpha: 1),
            .green: SKColor(red: 0.1, green: 0.6, blue: 0.25, alpha: 1),
            .yellow: SKColor(red: 0.75, green: 0.6, blue: 0.0, alpha: 1),
            .purple: SKColor(red: 0.5, green: 0.1, blue: 0.7, alpha: 1),
            .orange: SKColor(red: 0.75, green: 0.3, blue: 0.0, alpha: 1)
        ],
        backgroundGradient: LinearGradient(
            colors: [Color(white: 0.08), Color(white: 0.14)],
            startPoint: .top, endPoint: .bottom
        ),
        accentColor: Color(white: 0.9),
        textColor: .white,
        hudBackground: Color(white: 0.12),
        buttonBackground: Color(white: 0.20)
    )

    // MARK: Neon
    static let neonTheme = GameTheme(
        name: "Neon City", key: "neon",
        gridBackground: SKColor(red: 0.04, green: 0.04, blue: 0.12, alpha: 1),
        gridBorder: SKColor(red: 0.10, green: 0.80, blue: 0.90, alpha: 0.5),
        cellBackground: SKColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1),
        obstacleColor: SKColor(red: 0.30, green: 0.00, blue: 0.45, alpha: 1),
        arrowFillColors: [
            .white:  SKColor(red: 0.10, green: 0.90, blue: 1.00, alpha: 1),
            .red:    SKColor(red: 1.00, green: 0.10, blue: 0.50, alpha: 1),
            .blue:   SKColor(red: 0.10, green: 0.40, blue: 1.00, alpha: 1),
            .green:  SKColor(red: 0.10, green: 1.00, blue: 0.50, alpha: 1),
            .yellow: SKColor(red: 1.00, green: 1.00, blue: 0.10, alpha: 1),
            .purple: SKColor(red: 0.80, green: 0.10, blue: 1.00, alpha: 1),
            .orange: SKColor(red: 1.00, green: 0.50, blue: 0.10, alpha: 1)
        ],
        arrowStrokeColors: [:], // will fall back to fill
        backgroundGradient: LinearGradient(
            colors: [Color(red: 0.02, green: 0.02, blue: 0.10),
                     Color(red: 0.05, green: 0.02, blue: 0.15)],
            startPoint: .top, endPoint: .bottom
        ),
        accentColor: Color(red: 0.1, green: 0.9, blue: 1.0),
        textColor: Color(red: 0.1, green: 0.9, blue: 1.0),
        hudBackground: Color(red: 0.04, green: 0.04, blue: 0.16),
        buttonBackground: Color(red: 0.08, green: 0.08, blue: 0.24)
    )

    // MARK: Cyber
    static let cyberTheme = GameTheme(
        name: "Cyber", key: "cyber",
        gridBackground: SKColor(red: 0.05, green: 0.08, blue: 0.05, alpha: 1),
        gridBorder: SKColor(red: 0.20, green: 0.85, blue: 0.20, alpha: 0.6),
        cellBackground: SKColor(red: 0.06, green: 0.10, blue: 0.06, alpha: 1),
        obstacleColor: SKColor(red: 0.15, green: 0.40, blue: 0.15, alpha: 1),
        arrowFillColors: [
            .white:  SKColor(red: 0.20, green: 1.00, blue: 0.20, alpha: 1),
            .red:    SKColor(red: 1.00, green: 0.20, blue: 0.20, alpha: 1),
            .blue:   SKColor(red: 0.20, green: 0.80, blue: 1.00, alpha: 1),
            .green:  SKColor(red: 0.00, green: 1.00, blue: 0.40, alpha: 1),
            .yellow: SKColor(red: 1.00, green: 1.00, blue: 0.00, alpha: 1),
            .purple: SKColor(red: 0.80, green: 0.20, blue: 1.00, alpha: 1),
            .orange: SKColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1)
        ],
        arrowStrokeColors: [:],
        backgroundGradient: LinearGradient(
            colors: [Color(red: 0.02, green: 0.06, blue: 0.02),
                     Color(red: 0.04, green: 0.10, blue: 0.04)],
            startPoint: .top, endPoint: .bottom
        ),
        accentColor: Color(red: 0.2, green: 1.0, blue: 0.2),
        textColor: Color(red: 0.2, green: 1.0, blue: 0.2),
        hudBackground: Color(red: 0.04, green: 0.08, blue: 0.04),
        buttonBackground: Color(red: 0.06, green: 0.14, blue: 0.06)
    )

    // MARK: Nature
    static let natureTheme = GameTheme(
        name: "Nature", key: "nature",
        gridBackground: SKColor(red: 0.12, green: 0.20, blue: 0.12, alpha: 1),
        gridBorder: SKColor(red: 0.30, green: 0.50, blue: 0.25, alpha: 1),
        cellBackground: SKColor(red: 0.14, green: 0.23, blue: 0.14, alpha: 1),
        obstacleColor: SKColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1),
        arrowFillColors: [
            .white:  SKColor(red: 0.90, green: 0.95, blue: 0.80, alpha: 1),
            .red:    SKColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1),
            .blue:   SKColor(red: 0.30, green: 0.60, blue: 0.90, alpha: 1),
            .green:  SKColor(red: 0.20, green: 0.75, blue: 0.30, alpha: 1),
            .yellow: SKColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1),
            .purple: SKColor(red: 0.60, green: 0.30, blue: 0.80, alpha: 1),
            .orange: SKColor(red: 0.90, green: 0.50, blue: 0.20, alpha: 1)
        ],
        arrowStrokeColors: [:],
        backgroundGradient: LinearGradient(
            colors: [Color(red: 0.08, green: 0.14, blue: 0.08),
                     Color(red: 0.12, green: 0.20, blue: 0.10)],
            startPoint: .top, endPoint: .bottom
        ),
        accentColor: Color(red: 0.4, green: 0.8, blue: 0.3),
        textColor: Color(red: 0.9, green: 0.95, blue: 0.8),
        hudBackground: Color(red: 0.10, green: 0.18, blue: 0.10),
        buttonBackground: Color(red: 0.15, green: 0.28, blue: 0.15)
    )

    // MARK: Dark (OLED)
    static let darkTheme = GameTheme(
        name: "Pure Dark", key: "dark",
        gridBackground: SKColor(white: 0.06, alpha: 1),
        gridBorder: SKColor(white: 0.15, alpha: 1),
        cellBackground: SKColor(white: 0.08, alpha: 1),
        obstacleColor: SKColor(white: 0.22, alpha: 1),
        arrowFillColors: [
            .white:  SKColor(white: 0.85, alpha: 1),
            .red:    SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1),
            .blue:   SKColor(red: 0.20, green: 0.50, blue: 0.90, alpha: 1),
            .green:  SKColor(red: 0.20, green: 0.75, blue: 0.35, alpha: 1),
            .yellow: SKColor(red: 0.95, green: 0.80, blue: 0.15, alpha: 1),
            .purple: SKColor(red: 0.65, green: 0.25, blue: 0.88, alpha: 1),
            .orange: SKColor(red: 0.92, green: 0.50, blue: 0.15, alpha: 1)
        ],
        arrowStrokeColors: [:],
        backgroundGradient: LinearGradient(
            colors: [Color.black, Color(white: 0.06)],
            startPoint: .top, endPoint: .bottom
        ),
        accentColor: Color(white: 0.85),
        textColor: Color(white: 0.9),
        hudBackground: Color(white: 0.07),
        buttonBackground: Color(white: 0.12)
    )
}
