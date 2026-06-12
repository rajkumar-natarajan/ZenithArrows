// GameBoardView.swift
// ZenithArrows
// SwiftUI wrapper that embeds the SpriteKit GameScene.
// Updated: Feature 11 (trail overlay), Feature 15 (undo highlight),
//          Feature 17 (free hint), Feature 5 (replay button).

import SwiftUI
import SpriteKit

struct GameBoardView: View {

    let levelDefinition: LevelDefinition
    var onLevelComplete: ((Int) -> Void)? = nil
    var onQuit: (() -> Void)? = nil

    @StateObject private var gameState: GameState
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var trailVM = TrailEffectViewModel()     // Feature 11
    @StateObject private var boosters = BoosterManager.shared

    private let moveValidator = MoveValidator()
    private let hintEngine    = HintEngine()

    @State private var scene: GameScene?
    @State private var showPause = false
    @State private var showEndLevel = false
    @State private var completedStars = 0
    @State private var showTutorialStep: Int? = nil
    @State private var sceneSize: CGSize = .zero
    @State private var showReplay = false   // Feature 5
    @State private var hintsUsedThisLevel = 0

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
                        hintsUsedThisLevel += 1
                    },
                    onFreeHint: {  // Feature 17
                        HapticManager.shared.buttonTap()
                        AudioManager.shared.play(.hint)
                        gameState.useFreeHint(hintEngine: hintEngine)
                        hintsUsedThisLevel += 1
                    }
                )
                .padding(.top, 4)

                // Booster bar
                BoosterBarView(
                    gameState: gameState,
                    hintEngine: hintEngine,
                    onSkip: {
                        // Skip = instant 1-star complete
                        completedStars = 1
                        LevelManager.shared.saveProgress(levelID: levelDefinition.id, stars: 1)
                        ProgressManager.shared.recordLevelComplete(stars: 1, moves: gameState.moves)
                        showEndLevel = true
                    }
                )

                GeometryReader { geo in
                    ZStack {
                        SpriteView(scene: makeScene(size: geo.size),
                                   preferredFramesPerSecond: 120,
                                   options: [.allowsTransparency])
                            .frame(width: geo.size.width, height: geo.size.height)
                            .background(Color.clear)
                            .onAppear { sceneSize = geo.size }

                        // Feature 11 – Trail effect overlay
                        TrailEffectView(viewModel: trailVM)

                        // Feature 15 – Undo return highlight overlay label
                        if let undoID = gameState.undoReturnedArrowID {
                            UndoReturnLabel()
                                .transition(.scale.combined(with: .opacity))
                                .id(undoID)
                        }
                    }
                }
            }

            // Tutorial overlay
            // Tutorial hint — shown AFTER game starts so it never blocks touches
            if let step = showTutorialStep, step < tutorialSteps.count {
                // Non-blocking: game is already playing; overlay sits at bottom
                // without a full-screen touch-intercepting background
                VStack {
                    Spacer()
                    TutorialOverlayView(step: tutorialSteps[step]) {
                        withAnimation {
                            let next = step + 1
                            showTutorialStep = next < tutorialSteps.count ? next : nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
                }
                .allowsHitTesting(true)   // only the card itself is interactive
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .onAppear {
            // Always start playing immediately — tutorial is now a non-blocking overlay
            beginPlaying()
            if isTutorialLevel && levelDefinition.index == 1 {
                showTutorialStep = 0
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
                replayEngine: gameState.replayEngine,     // Feature 5
                hintEngine: hintEngine,
                grid: gameState.grid,
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
        hintsUsedThisLevel = 0
        StatisticsManager.shared.recordLevelStarted(levelID: levelDefinition.id)
        BoosterManager.shared.claimDailyBonus()
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
            BoosterManager.shared.rewardForLevel(stars: stars)
            StatisticsManager.shared.recordLevelCompleted(
                levelID: levelDefinition.id,
                moves: gameState.moves,
                time: gameState.elapsedTime,
                hintsUsed: hintsUsedThisLevel,
                boostersUsed: 0,
                maxCombo: gameState.comboEngine.currentCombo.streak
            )
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

// MARK: – Feature 15 Undo Return Label

private struct UndoReturnLabel: View {
    var body: some View {
        VStack {
            Spacer()
            Text("↩ Arrow returned")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(.bottom, 20)
        }
    }
}
