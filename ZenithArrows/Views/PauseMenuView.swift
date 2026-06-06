// PauseMenuView.swift
// ZenithArrows

import SwiftUI

struct PauseMenuView: View {

    @ObservedObject var gameState: GameState
    @StateObject private var theme = ThemeManager.shared

    var onResume: () -> Void
    var onRestart: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            theme.current.backgroundGradient.ignoresSafeArea()
                .opacity(0.97)

            VStack(spacing: 24) {
                Spacer()

                Text("Paused")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(theme.current.textColor)

                // Stats
                HStack(spacing: 24) {
                    MiniStat(value: "\(gameState.moves)", label: "Moves")
                    MiniStat(value: formatTime(gameState.elapsedTime), label: "Time")
                    MiniStat(value: "\(gameState.mistakes)", label: "Mistakes")
                }

                Divider()
                    .background(theme.current.textColor.opacity(0.15))
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    ActionButton(title: "Resume",
                                 systemImage: "play.fill",
                                 isPrimary: true,
                                 action: onResume)
                    ActionButton(title: "Restart Level",
                                 systemImage: "arrow.counterclockwise",
                                 isPrimary: false,
                                 action: onRestart)
                    ActionButton(title: "Quit to Menu",
                                 systemImage: "house.fill",
                                 isPrimary: false,
                                 action: onQuit)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct MiniStat: View {
    let value: String
    let label: String
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.accentColor)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.5))
        }
    }
}
