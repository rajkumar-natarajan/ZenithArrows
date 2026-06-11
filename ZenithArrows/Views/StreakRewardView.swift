// StreakRewardView.swift
// ZenithArrows
// Feature 9: Streak Reward popup shown when a streak milestone is reached.

import SwiftUI

struct StreakRewardView: View {

    let milestone: StreakMilestone
    var onClaim: () -> Void

    @StateObject private var theme = ThemeManager.shared
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 20) {
                // Flame icon + streak count
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 90, height: 90)
                        .blur(radius: 10)
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("\(milestone.id)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }

                Text(milestone.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(theme.current.textColor)

                Text(milestone.description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.6))
                    .multilineTextAlignment(.center)

                // Reward badge
                rewardBadge

                Button(action: onClaim) {
                    Text("Claim Reward")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(theme.current.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(theme.current.hudBackground, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    @ViewBuilder
    private var rewardBadge: some View {
        HStack(spacing: 10) {
            switch milestone.rewardType {
            case .hints:
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("+\(milestone.rewardValue) Hints")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
            case .themeUnlock:
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(.purple)
                Text("Theme Unlocked: \(milestone.rewardKey?.capitalized ?? "")")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
            case .starBonus:
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("+\(milestone.rewardValue) Bonus Stars")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}
