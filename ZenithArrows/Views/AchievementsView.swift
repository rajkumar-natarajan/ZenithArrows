// AchievementsView.swift
// ZenithArrows
// Feature 10: In-app achievements screen surfacing GameCenter milestone badges.

import SwiftUI

struct AchievementsView: View {

    @StateObject private var achievements = AchievementManager.shared
    @StateObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    // Progress summary
                    summaryHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(achievements.achievements) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.current.accentColor)
                }
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(achievements.unlockedCount) / \(achievements.totalCount)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
                Text("Achievements unlocked")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.5))
            }
            Spacer()
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(theme.current.accentColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(achievements.unlockedCount) / CGFloat(max(achievements.totalCount, 1)))
                    .stroke(theme.current.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(Double(achievements.unlockedCount) / Double(max(achievements.totalCount, 1)) * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.accentColor)
            }
            .frame(width: 64, height: 64)
        }
        .padding(16)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let achievement: Achievement
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked
                          ? theme.current.accentColor.opacity(0.2)
                          : Color.gray.opacity(0.1))
                    .frame(width: 52, height: 52)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(achievement.isUnlocked
                                      ? theme.current.accentColor
                                      : Color.gray.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked
                                      ? theme.current.textColor
                                      : Color.gray)
                Text(achievement.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.45))
                    .lineLimit(1)

                // Progress bar
                if !achievement.isUnlocked {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.current.accentColor)
                                .frame(width: geo.size.width * achievement.progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }

            Spacer()

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.current.accentColor)
                    .font(.system(size: 20))
            } else {
                Text("\(Int(achievement.progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.6))
            }
        }
        .padding(14)
        .background(
            achievement.isUnlocked
                ? theme.current.accentColor.opacity(0.07)
                : theme.current.buttonBackground,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(achievement.isUnlocked
                        ? theme.current.accentColor.opacity(0.25)
                        : Color.clear, lineWidth: 1)
        )
        .opacity(achievement.isUnlocked ? 1.0 : 0.7)
    }
}

// MARK: - Achievement Unlock Toast

struct AchievementToast: View {
    let achievement: Achievement
    var onDismiss: () -> Void

    @State private var visible = false
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked!")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text(achievement.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.85))
            )
            .padding(.horizontal, 20)
            .offset(y: visible ? 0 : -80)
            .opacity(visible ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                visible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { visible = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}
