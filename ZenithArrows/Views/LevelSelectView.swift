// LevelSelectView.swift
// ZenithArrows
// Grid of level thumbnails for a single world/chapter.

import SwiftUI

// MARK: - World Select

struct WorldSelectView: View {
    @StateObject private var levelManager = LevelManager.shared
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            theme.current.backgroundGradient.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(levelManager.worlds) { world in
                        NavigationLink(value: Route.levelSelect(world)) {
                            WorldCard(world: world)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Chapters")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct WorldCard: View {
    let world: World
    @StateObject private var theme = ThemeManager.shared

    var totalStars: Int { world.levels.map(\.bestStars).reduce(0, +) }
    var maxStars: Int   { world.levels.count * 3 }

    var body: some View {
        HStack(spacing: 16) {
            // World icon
            Text("W\(world.id)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(world.isUnlocked ? theme.current.accentColor : Color.gray)
                .frame(width: 56, height: 56)
                .background(
                    (world.isUnlocked ? theme.current.accentColor : Color.gray)
                        .opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(world.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(world.isUnlocked ? theme.current.textColor : Color.gray)

                Text(world.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.5))
                    .lineLimit(1)

                // Stars progress
                HStack(spacing: 3) {
                    ForEach(0..<min(maxStars, 15), id: \.self) { i in
                        Circle()
                            .fill(i < totalStars ? Color.yellow : Color.gray.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                    if maxStars > 15 {
                        Text("+")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.gray)
                    }
                }
            }

            Spacer()

            if !world.isUnlocked {
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.gray)
                    Text("\(world.requiredStarsToUnlock)★")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.gray)
                }
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(theme.current.textColor.opacity(0.3))
            }
        }
        .padding(16)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
        .opacity(world.isUnlocked ? 1 : 0.6)
    }
}

// MARK: - Level Select

struct LevelSelectView: View {
    let world: World
    @StateObject private var theme = ThemeManager.shared

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 90), spacing: 12)]

    var body: some View {
        ZStack {
            theme.current.backgroundGradient.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(world.levels) { level in
                        if level.isUnlocked {
                            NavigationLink(value: Route.game(level)) {
                                LevelCell(level: level)
                            }
                            .buttonStyle(.plain)
                        } else {
                            LockedLevelCell()
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(world.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Level Cell

struct LevelCell: View {
    let level: LevelDefinition
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 4) {
            Text("\(level.index)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.textColor)

            // Stars row
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < level.bestStars ? "star.fill" : "star")
                        .font(.system(size: 9))
                        .foregroundStyle(i < level.bestStars ? Color.yellow : Color.gray.opacity(0.4))
                }
            }

            // Feature 14 – Grid size indicator
            Text("\(level.gridRows)×\(level.gridCols)")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.45))

            // Difficulty dot with label on hover / always visible
            HStack(spacing: 2) {
                Circle()
                    .fill(difficultyColor)
                    .frame(width: 5, height: 5)
                Text(difficultyAbbrev)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(difficultyColor.opacity(0.8))
            }
        }
        .frame(width: 72, height: 80)
        .background(
            level.bestStars == 3
                ? Color.yellow.opacity(0.12)
                : theme.current.buttonBackground,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(level.bestStars == 3 ? Color.yellow.opacity(0.4) : Color.clear,
                        lineWidth: 1)
        )
    }

    private var difficultyColor: Color {
        switch level.difficulty {
        case .tutorial: return .blue
        case .easy:     return .green
        case .medium:   return .yellow
        case .hard:     return .orange
        case .expert:   return .red
        case .zen:      return .purple
        }
    }

    private var difficultyAbbrev: String {
        switch level.difficulty {
        case .tutorial: return "TUT"
        case .easy:     return "EZ"
        case .medium:   return "MED"
        case .hard:     return "HARD"
        case .expert:   return "EXP"
        case .zen:      return "ZEN"
        }
    }
}

struct LockedLevelCell: View {
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 18))
            .foregroundStyle(Color.gray.opacity(0.4))
            .frame(width: 72, height: 72)
            .background(theme.current.buttonBackground.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 12))
    }
}
