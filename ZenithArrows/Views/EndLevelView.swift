// EndLevelView.swift
// ZenithArrows
// Post-level celebration screen with star rating and options.

import SwiftUI

struct EndLevelView: View {

    let stars: Int
    let moves: Int
    let time: TimeInterval
    let levelID: String

    var onNextLevel: () -> Void
    var onReplay: () -> Void
    var onMenu: () -> Void

    @StateObject private var theme = ThemeManager.shared
    @State private var animatedStars: Int = 0
    @State private var showContent = false

    var body: some View {
        ZStack {
            theme.current.backgroundGradient.ignoresSafeArea()
                .opacity(0.96)

            VStack(spacing: 0) {
                Spacer()

                // MARK: Stars
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < animatedStars ? "star.fill" : "star")
                            .font(.system(size: i == 1 ? 56 : 44))
                            .foregroundStyle(i < animatedStars ? Color.yellow : Color.gray.opacity(0.3))
                            .shadow(color: i < animatedStars ? .yellow.opacity(0.6) : .clear,
                                    radius: 8)
                            .scaleEffect(i < animatedStars ? 1.0 : 0.8)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.5)
                                    .delay(Double(i) * 0.25),
                                value: animatedStars
                            )
                    }
                }
                .padding(.bottom, 28)

                // MARK: Title
                Text(stars == 3 ? "Perfect!" : stars == 2 ? "Great!" : "Level Clear")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
                    .opacity(showContent ? 1 : 0)

                Spacer(minLength: 20)

                // MARK: Stats
                if showContent {
                    HStack(spacing: 32) {
                        StatBadge(value: "\(moves)", label: "Moves", systemImage: "hand.tap")
                        StatBadge(value: formatTime(time), label: "Time", systemImage: "clock")
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 36)

                // MARK: Actions
                if showContent {
                    VStack(spacing: 12) {
                        ActionButton(title: "Next Level",
                                     systemImage: "arrow.right.circle.fill",
                                     isPrimary: true,
                                     action: onNextLevel)

                        HStack(spacing: 12) {
                            ActionButton(title: "Replay",
                                         systemImage: "arrow.counterclockwise",
                                         isPrimary: false,
                                         action: onReplay)
                            ActionButton(title: "Menu",
                                         systemImage: "house.fill",
                                         isPrimary: false,
                                         action: onMenu)
                        }

                        // Share button
                        ShareLink(item: shareText) {
                            Label("Share Result", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.current.accentColor)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            // Stagger star reveal
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                    if i <= stars { animatedStars = i }
                }
            }
            withAnimation(.easeOut.delay(0.9)) {
                showContent = true
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var shareText: String {
        "I cleared level \(levelID) in ZenithArrows with \(stars)⭐ in \(moves) moves! Can you beat it?"
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let systemImage: String
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.current.accentColor)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.textColor)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.5))
        }
        .frame(minWidth: 80)
        .padding(.vertical, 12)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isPrimary ? .black : theme.current.textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isPrimary
                    ? AnyShapeStyle(theme.current.accentColor)
                    : AnyShapeStyle(theme.current.buttonBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }
}
