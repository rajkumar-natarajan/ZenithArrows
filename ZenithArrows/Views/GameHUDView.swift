// GameHUDView.swift
// ZenithArrows
// Minimal in-game heads-up display: level info, lives, moves, controls.
// Updated: Feature 16 (par indicator), Feature 17 (free hint cooldown),
//          Feature 2 (combo label).

import SwiftUI

struct GameHUDView: View {

    @ObservedObject var gameState: GameState
    let levelTitle: String
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var comboEngine: ComboEngine

    var onPause: () -> Void
    var onUndo: () -> Void
    var onHint: () -> Void
    var onFreeHint: () -> Void

    @State private var movesBounce: Bool = false

    // Allow external combo engine or fall back to gameState's own
    init(gameState: GameState,
         levelTitle: String,
         onPause: @escaping () -> Void,
         onUndo: @escaping () -> Void,
         onHint: @escaping () -> Void,
         onFreeHint: @escaping () -> Void = {}) {
        self.gameState = gameState
        self.levelTitle = levelTitle
        self.onPause = onPause
        self.onUndo = onUndo
        self.onHint = onHint
        self.onFreeHint = onFreeHint
        _comboEngine = StateObject(wrappedValue: gameState.comboEngine)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Feature 2 – Combo banner
            if let comboText = comboEngine.lastComboText {
                Text(comboText)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 2)
            }

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
                        // Feature 16 – Move counter with par indicator
                        VStack(spacing: 1) {
                            Label("\(gameState.moves)", systemImage: "hand.tap")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(parColor)
                                .scaleEffect(movesBounce ? 1.25 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.4),
                                           value: movesBounce)
                                .onChange(of: gameState.moves) { _, _ in
                                    movesBounce = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        movesBounce = false
                                    }
                                }
                            Text("par \(gameState.parMoves)")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(theme.current.textColor.opacity(0.35))
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

                // Feature 17 – Free hint (cooldown) + paid hints
                VStack(spacing: 2) {
                    ZStack(alignment: .topTrailing) {
                        HUDButton(systemImage: "lightbulb.fill",
                                   isDisabled: gameState.hintsRemaining == 0 && !gameState.isFreeHintReady,
                                   action: gameState.hintsRemaining > 0 ? onHint : onFreeHint)
                        if gameState.hintsRemaining > 0 {
                            Text("\(gameState.hintsRemaining)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                                .background(Color.orange, in: Circle())
                                .offset(x: 5, y: -5)
                        } else if gameState.isFreeHintReady {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                                .frame(width: 14, height: 14)
                                .offset(x: 5, y: -5)
                        }
                    }
                    if !gameState.isFreeHintReady && gameState.hintsRemaining == 0 {
                        Text(gameState.freeHintCooldownLabel)
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(theme.current.textColor.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(
            theme.current.hudBackground
                .opacity(0.92)
                .ignoresSafeArea(edges: .top)
        )
        .animation(.easeInOut(duration: 0.2), value: comboEngine.lastComboText)
    }

    // Feature 16 – colour the move counter relative to par
    private var parColor: Color {
        if gameState.isUnderPar { return .green }
        if gameState.movesOverPar <= 2 { return theme.current.accentColor }
        return .orange
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
