// SettingsView.swift
// ZenithArrows
// Updated: Feature 18 (colorblind mode), Feature 20 (notification settings),
//          Feature 13 (locked theme display).

import SwiftUI

struct SettingsView: View {

    @StateObject private var audio    = AudioManager.shared
    @StateObject private var theme    = ThemeManager.shared
    @StateObject private var colorblind = ColorblindManager.shared
    @StateObject private var gridOverlay = GridOverlayManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = false
    @State private var showNotificationAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()

                List {
                    // MARK: Audio
                    Section("Audio") {
                        Toggle("Background Music", isOn: $audio.isMusicEnabled)
                        Toggle("Sound Effects", isOn: $audio.isSFXEnabled)
                    }
                    .listRowBackground(theme.current.buttonBackground)

                    // MARK: Accessibility – Feature 18
                    Section("Accessibility") {
                        Toggle("Colorblind Mode", isOn: $colorblind.isEnabled)
                        if colorblind.isEnabled {
                            Picker("Overlay Style", selection: $colorblind.mode) {
                                ForEach(ColorblindManager.ColorblindMode.allCases, id: \.self) { m in
                                    Text(m.rawValue.capitalized).tag(m)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Toggle("Show Moveable Indicators", isOn: $gridOverlay.showMoveableIndicators)
                    }
                    .listRowBackground(theme.current.buttonBackground)

                    // MARK: Notifications – Feature 20
                    Section("Notifications") {
                        Toggle("Daily Challenge Reminder", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { _, enabled in
                                if enabled {
                                    Task {
                                        let granted = await NotificationManager.shared.requestAuthorization()
                                        if !granted {
                                            notificationsEnabled = false
                                            showNotificationAlert = true
                                        }
                                    }
                                } else {
                                    NotificationManager.shared.cancelAll()
                                }
                            }
                    }
                    .listRowBackground(theme.current.buttonBackground)

                    // MARK: Appearance – Feature 13 theme locking
                    Section("Theme") {
                        ForEach(theme.displayThemes, id: \.theme.key) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.theme.name)
                                        .foregroundStyle(item.isUnlocked
                                                          ? theme.current.textColor
                                                          : Color.gray)
                                    if !item.isUnlocked, let req = item.requiredStars {
                                        Text("Unlock at \(req) ⭐ or streak reward")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.gray.opacity(0.7))
                                    }
                                }
                                Spacer()
                                if !item.isUnlocked {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                        .font(.system(size: 13))
                                } else if item.theme.key == theme.current.key {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.current.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard item.isUnlocked else { return }
                                theme.select(themeKey: item.theme.key)
                            }
                            .opacity(item.isUnlocked ? 1.0 : 0.6)
                        }
                    }
                    .listRowBackground(theme.current.buttonBackground)

                    // MARK: About
                    Section("About") {
                        HStack {
                            Text("Version")
                                .foregroundStyle(theme.current.textColor)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(theme.current.textColor.opacity(0.5))
                        }
                        Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                            .foregroundStyle(theme.current.accentColor)
                        Link("Rate on App Store", destination: URL(string: "https://apps.apple.com")!)
                            .foregroundStyle(theme.current.accentColor)
                    }
                    .listRowBackground(theme.current.buttonBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.current.accentColor)
                }
            }
            .alert("Notifications Disabled", isPresented: $showNotificationAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in iOS Settings to receive daily challenge reminders.")
            }
            .task {
                notificationsEnabled = await NotificationManager.shared.isAuthorized
            }
        }
    }
}

// MARK: - ShopView

struct ShopView: View {
    @StateObject private var theme   = ThemeManager.shared
    @StateObject private var progress = ProgressManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Remove Ads
                        ShopItem(
                            title: "Remove Ads",
                            description: "Enjoy ZenithArrows without any ads",
                            price: "$1.99",
                            systemImage: "xmark.shield.fill",
                            isPurchased: progress.hasRemovedAds
                        ) {
                            // Trigger StoreKit purchase for "com.zenith.removeads"
                        }

                        // Full Unlock
                        ShopItem(
                            title: "Full Game Unlock",
                            description: "Unlock all 1000+ levels forever",
                            price: "$3.99",
                            systemImage: "lock.open.fill",
                            isPurchased: progress.hasPremiumUnlock
                        ) {
                            // Trigger StoreKit purchase for "com.zenith.fullunlock"
                        }

                        // Hint Packs
                        ShopItem(title: "10 Hints", description: "Extra hints when you're stuck",
                                 price: "$0.99", systemImage: "lightbulb.fill",
                                 isPurchased: false) {
                            progress.addHints(10)
                        }

                        ShopItem(title: "50 Hints", description: "Big hint bundle — best value",
                                 price: "$2.99", systemImage: "lightbulb.max.fill",
                                 isPurchased: false) {
                            progress.addHints(50)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.current.accentColor)
                }
            }
        }
    }
}

struct ShopItem: View {
    let title: String
    let description: String
    let price: String
    let systemImage: String
    let isPurchased: Bool
    let action: () -> Void
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(theme.current.accentColor)
                .frame(width: 48, height: 48)
                .background(theme.current.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
                Text(description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.5))
            }

            Spacer()

            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 22))
            } else {
                Button(price, action: action)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.current.accentColor, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
