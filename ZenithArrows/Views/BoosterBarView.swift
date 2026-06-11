// BoosterBarView.swift
// ZenithArrows
//
// In-game booster action bar shown below the HUD.
// Displays coin balance and three booster buttons.
// Tapping a booster activates it (deducts coins) and awaits the player's
// next tap (for Erase booster) or executes immediately (Auto-Step, Skip).

import SwiftUI

struct BoosterBarView: View {

    @ObservedObject var gameState: GameState
    @StateObject private var boosters = BoosterManager.shared
    @StateObject private var theme = ThemeManager.shared
    let hintEngine: HintEngine
    var onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Coin balance
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("\(boosters.coins)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.current.buttonBackground, in: Capsule())

            Spacer()

            ForEach(BoosterType.allCases, id: \.self) { booster in
                boosterButton(booster)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(theme.current.hudBackground.opacity(0.85))
    }

    @ViewBuilder
    private func boosterButton(_ booster: BoosterType) -> some View {
        let isActive = boosters.pendingBooster == booster
        let canAfford = boosters.canAfford(booster)

        Button {
            handleBoosterTap(booster)
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: booster.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(isActive ? .black : (canAfford ? theme.current.accentColor : Color.gray.opacity(0.4)))
                        .frame(width: 38, height: 38)
                        .background(
                            isActive ? theme.current.accentColor : theme.current.buttonBackground,
                            in: Circle()
                        )
                    // Cost badge
                    Text("\(booster.coinCost)")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .background(.yellow, in: Circle())
                        .offset(x: 4, y: -4)
                }
                Text(booster.displayName)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(canAfford ? 0.6 : 0.25))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canAfford && boosters.pendingBooster != booster)
        .opacity(canAfford || isActive ? 1.0 : 0.5)
    }

    private func handleBoosterTap(_ booster: BoosterType) {
        // Cancel if same booster tapped again
        if boosters.pendingBooster == booster {
            boosters.cancelPending()
            return
        }

        switch booster {
        case .erase:
            // Activate: next arrow tap will be erased (handled in GameScene)
            boosters.activate(.erase)

        case .autoStep:
            // Execute immediately: play next optimal move
            guard boosters.activate(.autoStep) else { return }
            if let id = hintEngine.nextSafeMove(in: gameState.grid),
               let arrow = gameState.grid.activeArrows.first(where: { $0.id == id }),
               let path = MoveValidator().validateMove(arrow: arrow, in: gameState.grid) {
                gameState.handleTap(at: arrow.position, moveValidator: MoveValidator())
            }
            boosters.cancelPending()
            StatisticsManager.shared.recordBoosterUsed()

        case .skipLevel:
            // Execute via callback
            guard boosters.activate(.skipLevel) else { return }
            boosters.cancelPending()
            StatisticsManager.shared.recordBoosterUsed()
            onSkip()
        }
    }
}
