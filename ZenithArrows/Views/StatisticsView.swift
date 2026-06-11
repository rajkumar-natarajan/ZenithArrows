// StatisticsView.swift
// ZenithArrows
// Profile / statistics screen showing per-world completion rates,
// per-level best stats, and global lifetime totals.

import SwiftUI

struct StatisticsView: View {

    @StateObject private var stats  = StatisticsManager.shared
    @StateObject private var levels = LevelManager.shared
    @StateObject private var theme  = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        globalSummaryCard
                        ForEach(levels.worlds) { world in
                            WorldStatsCard(world: world)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.current.accentColor)
                }
            }
        }
    }

    private var globalSummaryCard: some View {
        VStack(spacing: 14) {
            Text("All Time")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCell(value: "\(stats.global.totalLevelsCompleted)", label: "Completed", icon: "checkmark.circle.fill")
                StatCell(value: stats.totalPlayTimeFormatted, label: "Play Time", icon: "clock.fill")
                StatCell(value: "\(stats.global.totalMovesAllTime)", label: "Moves", icon: "hand.tap.fill")
                StatCell(value: "\(stats.global.totalCombosAllTime)", label: "Combos", icon: "bolt.fill")
                StatCell(value: String(format: "%.0f%%", stats.overallCompletionRate * 100), label: "Win Rate", icon: "star.fill")
                StatCell(value: "\(stats.global.totalBoostersUsed)", label: "Boosters", icon: "wand.and.stars")
            }
        }
        .padding(16)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - World Stats Card

private struct WorldStatsCard: View {
    let world: World
    @StateObject private var stats = StatisticsManager.shared
    @StateObject private var theme = ThemeManager.shared
    @State private var expanded = false

    var completionPct: Double { StatisticsManager.shared.worldCompletionRate(world: world) }
    var earnedStars: Int { world.levels.map(\.bestStars).reduce(0, +) }
    var maxStars: Int { world.levels.count * 3 }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(world.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(world.isUnlocked ? theme.current.textColor : Color.gray)
                        Text("\(earnedStars) / \(maxStars) ★  ·  \(world.levels.count) levels")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(theme.current.textColor.opacity(0.45))
                    }
                    Spacer()
                    // Progress ring
                    ZStack {
                        Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: completionPct)
                            .stroke(theme.current.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(completionPct * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.current.accentColor)
                    }
                    .frame(width: 44, height: 44)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.current.textColor.opacity(0.4))
                        .padding(.leading, 4)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded level detail
            if expanded {
                Divider().background(theme.current.accentColor.opacity(0.15))
                LazyVStack(spacing: 0) {
                    ForEach(world.levels) { level in
                        LevelStatRow(level: level)
                        Divider().background(theme.current.accentColor.opacity(0.08))
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Level Stat Row

private struct LevelStatRow: View {
    let level: LevelDefinition
    @StateObject private var stats = StatisticsManager.shared
    @StateObject private var theme = ThemeManager.shared

    private var stat: LevelStat? { stats.stat(for: level.id) }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(level.index)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.5))
                .frame(width: 28, alignment: .center)

            // Stars
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < level.bestStars ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(i < level.bestStars ? Color.yellow : Color.gray.opacity(0.3))
                }
            }
            .frame(width: 42)

            Text(level.title ?? "Level \(level.index)")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.7))
                .lineLimit(1)

            Spacer()

            if let s = stat, s.completions > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Best: \(s.bestMoves == Int.max ? "-" : "\(s.bestMoves)") moves")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.5))
                    Text(s.bestTime == .infinity ? "" : formatTime(s.bestTime))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(theme.current.accentColor.opacity(0.7))
                }
            } else {
                Text(level.isUnlocked ? "Not played" : "Locked")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.gray.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value: String
    let label: String
    let icon: String
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(theme.current.accentColor)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.textColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.current.hudBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}
