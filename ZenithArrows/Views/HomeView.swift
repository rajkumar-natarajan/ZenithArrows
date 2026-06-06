// HomeView.swift
// ZenithArrows
// Root home screen: Play, Daily Challenge, Chapters, Shop, Settings.

import SwiftUI

struct HomeView: View {

    @StateObject private var levelManager  = LevelManager.shared
    @StateObject private var themeManager  = ThemeManager.shared
    @StateObject private var progressMgr   = ProgressManager.shared

    @State private var navigation: NavigationPath = NavigationPath()
    @State private var showSettings = false
    @State private var showShop = false

    var body: some View {
        NavigationStack(path: $navigation) {
            ZStack {
                themeManager.current.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: Header
                    header

                    Spacer(minLength: 20)

                    // MARK: Logo / Title
                    logoArea

                    Spacer(minLength: 32)

                    // MARK: Main Actions
                    VStack(spacing: 14) {
                        // Play (continues or starts first unlocked level)
                        MainMenuButton(
                            title: "Play",
                            subtitle: "Continue your journey",
                            systemImage: "play.fill",
                            accentColor: themeManager.current.accentColor
                        ) {
                            if let firstWorld = levelManager.worlds.first,
                               let firstLevel = firstWorld.levels.first(where: \.isUnlocked) {
                                navigation.append(Route.game(firstLevel))
                            }
                        }

                        // Daily Challenge
                        if let daily = levelManager.dailyChallenge {
                            MainMenuButton(
                                title: "Daily Challenge",
                                subtitle: "New puzzle every day",
                                systemImage: "calendar",
                                accentColor: .orange
                            ) {
                                navigation.append(Route.game(daily))
                            }
                        }

                        // Chapters
                        MainMenuButton(
                            title: "Chapters",
                            subtitle: "\(progressMgr.totalStars) ★ collected",
                            systemImage: "map",
                            accentColor: .yellow
                        ) {
                            navigation.append(Route.worldSelect)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)

                    // MARK: Bottom Row
                    HStack(spacing: 24) {
                        BottomBarButton(systemImage: "bag.fill", label: "Shop") {
                            showShop = true
                        }
                        BottomBarButton(systemImage: "gearshape.fill", label: "Settings") {
                            showSettings = true
                        }
                        BottomBarButton(systemImage: "trophy.fill", label: "Leaderboard") {
                            // Game Center Leaderboard
                        }
                    }
                    .padding(.bottom, 32)
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
                    .navigationBarHidden(true)
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShop) { ShopView() }
        .onAppear { progressMgr.authenticateGameCenter() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            // Daily streak badge
            if progressMgr.dailyStreak > 1 {
                Label("\(progressMgr.dailyStreak) day streak", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
            Spacer()
            // Stars count
            Label("\(progressMgr.totalStars)", systemImage: "star.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var logoArea: some View {
        VStack(spacing: 6) {
            Text("↑")
                .font(.system(size: 64))
                .rotationEffect(.degrees(45))
                .foregroundStyle(themeManager.current.accentColor)
            Text("ZenithArrows")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(themeManager.current.textColor)
            Text("LOGIC PUZZLE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.current.textColor.opacity(0.45))
                .kerning(3)
        }
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.current.textColor)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.current.textColor.opacity(0.3))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 22))
                    .foregroundStyle(theme.current.accentColor)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}
