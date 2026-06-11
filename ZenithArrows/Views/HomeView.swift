// HomeView.swift
// ZenithArrows
// Root home screen: Play, Daily Challenge, Weekly Challenge, Chapters, Shop, Settings.
// Updated: Feature 6 (weekly challenges), Feature 9 (streak reward popup),
//          Feature 10 (achievements), Feature 20 (notifications).

import SwiftUI

struct HomeView: View {

    @StateObject private var levelManager  = LevelManager.shared
    @StateObject private var themeManager  = ThemeManager.shared
    @StateObject private var progressMgr   = ProgressManager.shared
    @StateObject private var streakRewards = StreakRewardManager.shared
    @StateObject private var achievements  = AchievementManager.shared

    @State private var navigation: NavigationPath = NavigationPath()
    @State private var showSettings = false
    @State private var showShop = false
    @State private var showWeekly = false
    @State private var showAchievements = false
    @State private var showStatistics = false
    @State private var showEvents = false
    @State private var logoRotation: Double = 0
    @State private var appeared = false

    // First unlocked level that the player hasn't 3-starred yet
    private var continueLevel: LevelDefinition? {
        for world in levelManager.worlds where world.isUnlocked {
            for level in world.levels where level.isUnlocked && level.bestStars < 3 {
                return level
            }
        }
        return levelManager.worlds.first?.levels.first
    }

    private var totalLevelCount: Int {
        levelManager.worlds.flatMap(\.levels).count
    }

    var body: some View {
        NavigationStack(path: $navigation) {
            ZStack {
                themeManager.current.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 12)
                    logoArea
                    Spacer(minLength: 28)
                    menuButtons
                    Spacer(minLength: 32)
                    bottomBar
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                // Feature 9 – Streak reward popup
                if let reward = streakRewards.pendingReward {
                    StreakRewardView(milestone: reward) {
                        streakRewards.dismissPendingReward()
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }

                // Feature 10 – Achievement unlock toast
                if let newAch = achievements.newlyUnlocked {
                    AchievementToast(achievement: newAch) {
                        achievements.dismissNewUnlock()
                    }
                    .zIndex(9)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .worldSelect:
                    WorldSelectView()
                case .levelSelect(let world):
                    LevelSelectView(world: world)
                case .game(let level):
                    GameBoardView(
                        levelDefinition: level,
                        onLevelComplete: { _ in navigation.removeLast() },
                        onQuit: { navigation.removeLast() }
                    )
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showWeekly) { WeeklyChallengeView() }
        .sheet(isPresented: $showAchievements) { AchievementsView() }
        .sheet(isPresented: $showStatistics) { StatisticsView() }
        .sheet(isPresented: $showEvents) { SeasonalEventView() }
        .onAppear {
            progressMgr.authenticateGameCenter()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                logoRotation = 360
            }
            // Feature 9 – check streak rewards on each app open
            progressMgr.checkStreakRewards()
            // Feature 20 – request notifications on first launch
            Task { await NotificationManager.shared.requestAuthorization() }
            NotificationManager.shared.clearBadge()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            if progressMgr.dailyStreak > 1 {
                Label("\(progressMgr.dailyStreak)d streak", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
            Spacer()
            // Feature 10 – achievements quick-access
            Button {
                showAchievements = true
            } label: {
                Label("\(achievements.unlockedCount)/\(achievements.totalCount)", systemImage: "trophy.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.yellow.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            Label("\(progressMgr.totalStars)", systemImage: "star.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var logoArea: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(themeManager.current.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                Text("↑")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(themeManager.current.accentColor)
                    .rotationEffect(.degrees(logoRotation + 45))
            }

            Text("ZenithArrows")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(themeManager.current.textColor)

            Text("LOGIC PUZZLE")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.current.textColor.opacity(0.4))
                .kerning(3)
        }
    }

    private var menuButtons: some View {
        VStack(spacing: 12) {
            // Continue / Play
            if let level = continueLevel {
                let worldName = levelManager.worlds.first(where: { $0.id == level.worldID })?.name ?? "World"
                MainMenuButton(
                    title: "Continue",
                    subtitle: "\(worldName) · Level \(level.index)",
                    systemImage: "play.fill",
                    accentColor: themeManager.current.accentColor
                ) {
                    HapticManager.shared.buttonTap()
                    navigation.append(Route.game(level))
                }
            }

            // Daily Challenge
            if let daily = levelManager.dailyChallenge {
                MainMenuButton(
                    title: "Daily Challenge",
                    subtitle: "Fresh puzzle every day",
                    systemImage: "calendar",
                    accentColor: .orange
                ) {
                    HapticManager.shared.buttonTap()
                    navigation.append(Route.game(daily))
                }
            }

            // Feature 6 – Weekly Challenge
            MainMenuButton(
                title: "Weekly Challenge",
                subtitle: WeeklyChallengeManager.shared.timeRemainingFormatted.isEmpty
                    ? "New hard puzzle every Monday"
                    : "Resets in \(WeeklyChallengeManager.shared.timeRemainingFormatted)",
                systemImage: "calendar.badge.clock",
                accentColor: .purple
            ) {
                HapticManager.shared.buttonTap()
                showWeekly = true
            }

            // Chapters
            MainMenuButton(
                title: "Chapters",
                subtitle: "\(progressMgr.totalStars) ★  ·  \(totalLevelCount) levels",
                systemImage: "map",
                accentColor: .yellow
            ) {
                HapticManager.shared.buttonTap()
                navigation.append(Route.worldSelect)
            }
        }
        .padding(.horizontal, 22)
    }

    private var bottomBar: some View {
        HStack(spacing: 28) {
            BottomBarButton(systemImage: "bag.fill", label: "Shop") {
                showShop = true
            }
            BottomBarButton(systemImage: "chart.bar.fill", label: "Stats") {
                showStatistics = true
            }
            BottomBarButton(systemImage: "sparkles", label: "Events") {
                showEvents = true
            }
            BottomBarButton(systemImage: "gearshape.fill", label: "Settings") {
                showSettings = true
            }
            BottomBarButton(systemImage: "trophy.fill", label: "Leaderboard") {
                HapticManager.shared.buttonTap()
                // TODO: present Game Center Leaderboard
            }
        }
        .padding(.bottom, 36)
    }
}

// MARK: - Route

enum Route: Hashable {
    case worldSelect
    case levelSelect(World)
    case game(LevelDefinition)
}

extension World: Hashable {
    static func == (lhs: World, rhs: World) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension LevelDefinition: Hashable {
    static func == (lhs: LevelDefinition, rhs: LevelDefinition) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Menu Buttons

struct MainMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 42, height: 42)
                    .background(accentColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.current.textColor)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.45))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.current.textColor.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.easeOut(duration: 0.15)) { pressed = false } }
        )
    }
}

struct BottomBarButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.current.accentColor)
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}
