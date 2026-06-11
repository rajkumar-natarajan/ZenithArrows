// EndLevelView.swift
// ZenithArrows
// Post-level celebration screen with star rating and options.
// Updated: Feature 12 (per-star haptic/sound), Feature 5 (replay solution).

import SwiftUI

struct EndLevelView: View {

    let stars: Int
    let moves: Int
    let time: TimeInterval
    let levelTitle: String

    // Feature 5 – replay support
    var replayEngine: ReplayEngine? = nil
    var hintEngine: HintEngine? = nil
    var grid: GridModel? = nil

    var onNextLevel: () -> Void
    var onReplay: () -> Void
    var onMenu: () -> Void

    @StateObject private var theme = ThemeManager.shared
    @State private var animatedStars: Int = 0
    @State private var showContent = false
    @State private var headerScale: CGFloat = 0.6
    @State private var showSolutionReplay = false  // Feature 5

    var body: some View {
        ZStack {
            theme.current.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Feature 12 – Stars animate one-by-one, each with sound + haptic
                HStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            if i < animatedStars {
                                Circle()
                                    .fill(Color.yellow.opacity(0.18))
                                    .frame(width: 72, height: 72)
                                    .blur(radius: 8)
                            }
                            Image(systemName: i < animatedStars ? "star.fill" : "star")
                                .font(.system(size: i == 1 ? 52 : 42))
                                .foregroundStyle(i < animatedStars
                                                  ? Color.yellow
                                                  : theme.current.textColor.opacity(0.2))
                                .shadow(color: i < animatedStars ? .yellow.opacity(0.7) : .clear,
                                        radius: 10)
                                .scaleEffect(i < animatedStars ? 1.0 : 0.75)
                                .animation(
                                    .spring(response: 0.35, dampingFraction: 0.45)
                                        .delay(Double(i) * 0.22),
                                    value: animatedStars
                                )
                        }
                    }
                }
                .padding(.bottom, 24)

                // Title
                VStack(spacing: 6) {
                    Text(stars == 3 ? "Perfect!" : stars == 2 ? "Great Job!" : "Level Clear")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(theme.current.textColor)
                    Text(levelTitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.45))
                }
                .scaleEffect(headerScale)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.7),
                            value: showContent)

                Spacer(minLength: 24)

                // Stats
                if showContent {
                    HStack(spacing: 28) {
                        StatBadge(value: "\(moves)", label: "Moves", systemImage: "hand.tap")
                        StatBadge(value: formatTime(time), label: "Time", systemImage: "clock")
                        StatBadge(value: stars == 3 ? "✦✦✦" : stars == 2 ? "✦✦" : "✦",
                                  label: "Stars", systemImage: "star")
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Spacer(minLength: 32)

                // Actions
                if showContent {
                    VStack(spacing: 11) {
                        ActionButton(title: "Next Level",
                                     systemImage: "arrow.right.circle.fill",
                                     isPrimary: true,
                                     action: onNextLevel)
                        HStack(spacing: 11) {
                            ActionButton(title: "Replay",
                                         systemImage: "arrow.counterclockwise",
                                         isPrimary: false,
                                         action: onReplay)
                            ActionButton(title: "Menu",
                                         systemImage: "house.fill",
                                         isPrimary: false,
                                         action: onMenu)
                        }
                        // Feature 5 – Watch Solution Replay
                        if replayEngine != nil {
                            Button {
                                showSolutionReplay = true
                                if let e = replayEngine, let h = hintEngine, let g = grid {
                                    e.startOptimalReplay(grid: g, hintEngine: h)
                                }
                            } label: {
                                Label("Watch Solution", systemImage: "play.circle")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.current.accentColor)
                            }
                            .padding(.top, 2)
                        }
                        ShareLink(item: shareText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.current.accentColor)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 44)
            }
        }
        .onAppear {
            // Feature 12 – Staggered star reveal with per-star haptic + sound
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.28) {
                    if i <= stars {
                        animatedStars = i
                        AudioManager.shared.play(.star)
                        HapticManager.shared.starEarned()
                    }
                }
            }
            withAnimation(.easeOut.delay(0.8)) {
                showContent = true
                headerScale = 1.0
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var shareText: String {
        "I cleared \(levelTitle) in ZenithArrows with \(stars)⭐ in \(moves) moves! 🎯"
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let systemImage: String
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(theme.current.accentColor)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.textColor)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.45))
        }
        .frame(minWidth: 75)
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
            .padding(.vertical, 15)
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
