// GameBoardView.swift
// ZenithArrows
// SwiftUI wrapper that embeds the SpriteKit GameScene.

import SwiftUI
import SpriteKit

struct GameBoardView: View {

    let levelDefinition: LevelDefinition
    var onLevelComplete: ((Int) -> Void)? = nil
    var onQuit: (() -> Void)? = nil

    @StateObject private var gameState: GameState
    @StateObject private var themeManager = ThemeManager.shared

    private let moveValidator = MoveValidator()
    private let hintEngine    = HintEngine()

    @State private var scene: GameScene?
    @State private var showPause = false
    @State private var showEndLevel = false
    @State private var completedStars = 0
    @State private var showTutorialStep: Int? = nil
    @State private var sceneSize: CGSize = .zero

    private var isTutorialLevel: Bool {
        levelDefinition.difficulty == .tutorial &&
        levelDefinition.index <= 5
    }

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
            themeManager.current.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUDView(
                    gameState: gameState,
                    levelTitle: levelDefinition.title ?? "Level \(levelDefinition.index)",
                    onPause: {
                        HapticManager.shared.buttonTap()
                        gameState.pause()
                        showPause = true
                    },
                    onUndo: {
                        guard gameState.canUndo else { return }
                        HapticManager.shared.buttonTap()
                        AudioManager.shared.play(.buttonTap)
                        gameState.undo()
                        scene?.rebuild()
                    },
                    onHint: {
                        HapticManager.shared.buttonTap()
                        AudioManager.shared.play(.hint)
                        gameState.useHint(hintEngine: hintEngine)
                    }
                )
                .padding(.top, 4)

                GeometryReader { geo in
                    SpriteView(scene: makeScene(size: geo.size),
                               preferredFramesPerSecond: 120,
                               options: [.allowsTransparency])
                        .frame(width: geo.size.width, height: geo.size.height)
                        .background(Color.clear)
                        .onAppear { sceneSize = geo.size }
                }
            }

            // Tutorial overlay
            if let step = showTutorialStep, step < tutorialSteps.count {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .transition(.opacity)
                TutorialOverlayView(step: tutorialSteps[step]) {
                    withAnimation {
                        let next = step + 1
                        showTutorialStep = next < tutorialSteps.count ? next : nil
                        if showTutorialStep == nil { beginPlaying() }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            if isTutorialLevel && levelDefinition.index == 1 {
                showTutorialStep = 0
            } else {
                beginPlaying()
            }
        }
        .onChange(of: gameState.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .navigationBarHidden(true)
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
                levelTitle: levelDefinition.title ?? "Level \(levelDefinition.index)",
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

    // MARK: - Helpers

    private func beginPlaying() {
        guard gameState.phase == .idle else { return }
        gameState.phase = .playing
        gameState.startTimer()
    }

    @MainActor
    private func makeScene(size: CGSize) -> GameScene {
        if let existing = scene { return existing }
        let s = GameScene(size: size)
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear
        s.gameState     = gameState
        s.moveValidator = moveValidator
        s.hintEngine    = hintEngine
        s.theme         = themeManager.current
        scene = s
        return s
    }

    private func handlePhaseChange(_ phase: GamePhase) {
        switch phase {
        case .levelComplete(let stars):
            completedStars = stars
            LevelManager.shared.saveProgress(levelID: levelDefinition.id, stars: stars)
            ProgressManager.shared.recordLevelComplete(stars: stars, moves: gameState.moves)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                showEndLevel = true
            }
        case .levelFailed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showPause = true
            }
        default: break
        }
    }
}
