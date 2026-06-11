// WeeklyChallengeView.swift
// ZenithArrows
// Feature 6: Weekly Challenge UI — entry card and leaderboard display.

import SwiftUI

struct WeeklyChallengeView: View {

    @StateObject private var weekly = WeeklyChallengeManager.shared
    @StateObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToGame = false
    @State private var selectedLevel: LevelDefinition? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Timer header
                        timerHeader

                        // Current challenge card
                        if let challenge = weekly.current {
                            currentChallengeCard(challenge: challenge)
                        } else {
                            Text("No weekly challenge available")
                                .foregroundStyle(theme.current.textColor.opacity(0.5))
                        }

                        // Past challenges
                        if !weekly.past.isEmpty {
                            pastChallengesSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Weekly Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.current.accentColor)
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                if let level = selectedLevel {
                    GameBoardView(
                        levelDefinition: level,
                        onLevelComplete: { stars in
                            weekly.recordCompletion(stars: stars, score: stars * 100)
                            navigateToGame = false
                        },
                        onQuit: { navigateToGame = false }
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var timerHeader: some View {
        HStack {
            Label("Resets in \(weekly.timeRemainingFormatted)", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.current.accentColor.opacity(0.12), in: Capsule())
            Spacer()
        }
    }

    private func currentChallengeCard(challenge: WeeklyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week's Challenge")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.current.textColor.opacity(0.5))
                    Text(challenge.levelDefinition.title ?? "Weekly Puzzle")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(theme.current.textColor)
                }
                Spacer()
                if challenge.completed {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < challenge.bestStars ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundStyle(i < challenge.bestStars ? .yellow : .gray.opacity(0.3))
                            }
                        }
                        Text("Best: \(challenge.bestScore)")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.current.textColor.opacity(0.5))
                    }
                }
            }

            // Grid info
            HStack(spacing: 16) {
                Label("\(challenge.levelDefinition.gridRows)×\(challenge.levelDefinition.gridCols)", systemImage: "grid")
                Label("\(challenge.levelDefinition.arrows.count) arrows", systemImage: "arrow.up")
                Label(challenge.levelDefinition.difficulty.rawValue.capitalized, systemImage: "flame")
            }
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(theme.current.textColor.opacity(0.55))

            // Play button
            Button {
                selectedLevel = challenge.levelDefinition
                navigateToGame = true
            } label: {
                HStack {
                    Image(systemName: challenge.completed ? "arrow.counterclockwise" : "play.fill")
                    Text(challenge.completed ? "Replay" : "Play Now")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.current.accentColor, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.current.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var pastChallengesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past Challenges")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.55))
                .padding(.leading, 4)

            ForEach(weekly.past) { past in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(past.weekID)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.current.textColor)
                        Text(past.completed ? "Completed · \(past.bestScore) pts" : "Not played")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(theme.current.textColor.opacity(0.45))
                    }
                    Spacer()
                    if past.completed {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < past.bestStars ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundStyle(i < past.bestStars ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(12)
                .background(theme.current.buttonBackground.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 10))
                .opacity(past.completed ? 1.0 : 0.55)
            }
        }
    }
}
