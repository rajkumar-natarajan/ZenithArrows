// GameHUDView.swift
// ZenithArrows
// Minimal in-game heads-up display: level info, lives, moves, controls.

import SwiftUI

struct GameHUDView: View {

    @ObservedObject var gameState: GameState
    let levelTitle: String
    @StateObject private var theme = ThemeManager.shared

    var onPause: () -> Void
    var onUndo: () -> Void
    var onHint: () -> Void

    @State private var movesBounce: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Pause
            HUDButton(systemImage: "pause.fill", action: onPause)

            Spacer()

            // Centre cluster
            VStack(spacing: 2) {
                Text(levelTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 16) {
                    // Move counter with bounce animation
                    Label("\(gameState.moves)", systemImage: "hand.tap")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.current.accentColor)
                        .scaleEffect(movesBounce ? 1.25 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.4),
                                   value: movesBounce)
                        .onChange(of: gameState.moves) { _, _ in
                            movesBounce = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                movesBounce = false
                            }
                        }

                    // Lives (hearts)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < gameState.lives ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundStyle(i < gameState.lives
                                                  ? Color.red
                                                  : theme.current.textColor.opacity(0.25))
                                .scaleEffect(i < gameState.lives ? 1.0 : 0.85)
                                .animation(.spring(response: 0.3), value: gameState.lives)
                        }
                    }

                    // Timer
                    Label(formatTime(gameState.elapsedTime), systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.65))
                }
            }

            Spacer()

            // Undo
            HUDButton(systemImage: "arrow.uturn.backward",
                       isDisabled: !gameState.canUndo,
                       action: onUndo)

            // Hint with badge
            ZStack(alignment: .topTrailing) {
                HUDButton(systemImage: "lightbulb.fill",
                           isDisabled: gameState.hintsRemaining == 0,
                           action: onHint)
                if gameState.hintsRemaining > 0 {
                    Text("\(gameState.hintsRemaining)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(Color.orange, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            theme.current.hudBackground
                .opacity(0.92)
                .ignoresSafeArea(edges: .top)
        )
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDisabled
                                  ? theme.current.textColor.opacity(0.2)
                                  : theme.current.accentColor)
                .frame(width: 38, height: 38)
                .background(theme.current.buttonBackground, in: Circle())
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}
