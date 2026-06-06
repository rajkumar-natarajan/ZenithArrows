// GameBoardView.swift
// ZenithArrows
// SwiftUI wrapper that embeds the SpriteKit GameScene.
// This view owns the GameState and wires up all dependencies.

import SwiftUI
import SpriteKit

struct GameBoardView: View {

    let levelDefinition: LevelDefinition
    var onLevelComplete: ((Int) -> Void)? = nil  // stars
    var onQuit: (() -> Void)? = nil

    @StateObject private var gameState: GameState
    @StateObject private var themeManager = ThemeManager.shared

    private let moveValidator = MoveValidator()
    private let hintEngine    = HintEngine()
    private let haptic        = HapticManager.shared
    private let audio         = AudioManager.shared

    @State private var scene: GameScene?
    @State private var showPause = false
    @State private var showEndLevel = false
    @State private var completedStars = 0

    init(levelDefinition: LevelDefinition,
         onLevelComplete: ((Int) -> Void)? = nil,
         onQuit: (() -> Void)? = nil) {
        self.levelDefinition = levelDefinition
        self.onLevelComplete = onLevelComplete
        self.onQuit = onQuit
        _gameState = StateObject(wrappedValue: GameState(levelDefinition: levelDefinition))
    }

    var body: some View {
        ZStack {
            // MARK: Background
            themeManager.current.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: HUD
                GameHUDView(
                    gameState: gameState,
                    onPause: {
                        haptic.buttonTap()
                        gameState.pause()
                        showPause = true
                    },
                    onUndo: {
                        guard gameState.canUndo else { return }
                        haptic.buttonTap()
                        audio.play(.buttonTap)
                        gameState.undo()
                        scene?.rebuild()
                    },
                    onHint: {
                        haptic.buttonTap()
                        audio.play(.hint)
                        gameState.useHint(hintEngine: hintEngine)
                    }
                )
                .padding(.top, 8)

                // MARK: SpriteKit Game Board
                GeometryReader { geo in
                    SpriteView(scene: makeScene(size: geo.size),
                               preferredFramesPerSecond: 120,
                               options: [.allowsTransparency])
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.clear)
                }
            }
        }
        .onAppear {
            gameState.phase = .playing
            gameState.startTimer()
        }
        .onChange(of: gameState.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .fullScreenCover(isPresented: $showPause) {
            PauseMenuView(
                gameState: gameState,
                onResume: {
                    gameState.resume()
                    showPause = false
                },
                onRestart: {
                    showPause = false
                    gameState.restart()
                    scene?.rebuild()
                },
                onQuit: {
                    showPause = false
                    onQuit?()
                }
            )
        }
        .fullScreenCover(isPresented: $showEndLevel) {
            EndLevelView(
                stars: completedStars,
                moves: gameState.moves,
                time: gameState.elapsedTime,
                levelID: levelDefinition.id,
                onNextLevel: {
                    showEndLevel = false
                    onLevelComplete?(completedStars)
                },
                onReplay: {
                    showEndLevel = false
                    gameState.restart()
                    scene?.rebuild()
                },
                onMenu: {
                    showEndLevel = false
                    onQuit?()
                }
            )
        }
    }

    // MARK: - Scene Construction

    @MainActor
    private func makeScene(size: CGSize) -> GameScene {
        if let existing = scene { return existing }
        let s = GameScene(size: size)
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear
        s.gameState    = gameState
        s.moveValidator = moveValidator
        s.hintEngine   = hintEngine
        s.theme        = themeManager.current
        scene = s
        return s
    }

    // MARK: - Phase Handling

    private func handlePhaseChange(_ phase: GamePhase) {
        switch phase {
        case .levelComplete(let stars):
            completedStars = stars
            LevelManager.shared.saveProgress(levelID: levelDefinition.id, stars: stars)
            ProgressManager.shared.recordLevelComplete(stars: stars, moves: gameState.moves)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showEndLevel = true
            }
        case .levelFailed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // Show restart prompt via pause menu in failed state
                showPause = true
            }
        default: break
        }
    }
}
