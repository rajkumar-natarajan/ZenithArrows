// GameHUDView.swift
// ZenithArrows
// Minimal in-game heads-up display: level info, lives, moves, controls.

import SwiftUI

struct GameHUDView: View {

    @ObservedObject var gameState: GameState
    @StateObject private var theme = ThemeManager.shared

    var onPause: () -> Void
    var onUndo: () -> Void
    var onHint: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // MARK: Pause
            HUDButton(systemImage: "pause.fill", action: onPause)

            Spacer()

            // MARK: Level / Moves / Lives
            VStack(spacing: 2) {
                Text(gameState.levelDefinition.title ?? gameState.levelDefinition.id)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.6))

                HStack(spacing: 14) {
                    // Moves
                    Label("\(gameState.moves)", systemImage: "hand.tap")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.current.accentColor)

                    // Lives (hearts)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < gameState.lives ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundStyle(i < gameState.lives
                                                  ? Color.red
                                                  : theme.current.textColor.opacity(0.3))
                        }
                    }

                    // Timer
                    Label(formatTime(gameState.elapsedTime), systemImage: "clock")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.7))
                }
            }

            Spacer()

            // MARK: Undo
            HUDButton(systemImage: "arrow.uturn.backward",
                       isDisabled: !gameState.canUndo,
                       action: onUndo)

            // MARK: Hint (with count badge)
            ZStack(alignment: .topTrailing) {
                HUDButton(systemImage: "lightbulb.fill",
                           isDisabled: gameState.hintsRemaining == 0,
                           action: onHint)
                if gameState.hintsRemaining > 0 {
                    Text("\(gameState.hintsRemaining)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.orange, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.current.hudBackground.opacity(0.85))
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Reusable HUD Button

struct HUDButton: View {
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isDisabled
                                  ? theme.current.textColor.opacity(0.25)
                                  : theme.current.accentColor)
                .frame(width: 40, height: 40)
                .background(theme.current.buttonBackground, in: Circle())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}
