// SeasonalEventView.swift
// ZenithArrows
// Displays the current seasonal event banner and level list.

import SwiftUI

struct SeasonalEventView: View {

    @StateObject private var events = SeasonalEventManager.shared
    @StateObject private var theme  = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLevel: LevelDefinition? = nil
    @State private var navigateToGame = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if let event = events.activeEvent {
                            activeEventCard(event)
                        } else {
                            noActiveEventCard
                        }
                        pastEventsSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Events")
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
                        onLevelComplete: { _ in navigateToGame = false },
                        onQuit: { navigateToGame = false }
                    )
                }
            }
        }
    }

    private func activeEventCard(_ event: SeasonalEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: event.iconSystemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: event.accentColorHex) ?? .orange)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LIVE NOW")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green, in: Capsule())
                        Text("\(event.daysRemaining)d left")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(theme.current.textColor.opacity(0.5))
                    }
                    Text(event.name)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(theme.current.textColor)
                    Text(event.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(theme.current.textColor.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Reward badge
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(Color(hex: event.accentColorHex) ?? .orange)
                Text("Reward: \(event.rewardCoins) coins" + (event.rewardThemeKey != nil ? " + Theme Unlock" : ""))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.current.hudBackground, in: RoundedRectangle(cornerRadius: 8))

            // Level buttons
            VStack(spacing: 8) {
                ForEach(Array(event.levelIDs.enumerated()), id: \.offset) { idx, levelID in
                    Button {
                        if let lvl = events.eventLevel(id: levelID) {
                            selectedLevel = lvl
                            navigateToGame = true
                        }
                    } label: {
                        HStack {
                            Text("Level \(idx + 1)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.current.textColor)
                            Spacer()
                            Image(systemName: "play.fill")
                                .foregroundStyle(theme.current.accentColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.current.buttonBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: event.accentColorHex)?.opacity(0.4) ?? Color.clear, lineWidth: 1.5)
                )
        )
    }

    private var noActiveEventCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(theme.current.textColor.opacity(0.3))
            Text("No Active Event")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.5))
            Text("Check back for seasonal challenges and exclusive rewards!")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(theme.current.textColor.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(theme.current.buttonBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var pastEventsSection: some View {
        let past = events.events.filter { !$0.isActive }
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Past Events")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.current.textColor.opacity(0.5))
                    .padding(.leading, 4)
                ForEach(past) { event in
                    HStack {
                        Image(systemName: event.iconSystemImage)
                            .foregroundStyle(Color(hex: event.accentColorHex) ?? .gray)
                        Text(event.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(theme.current.textColor.opacity(0.6))
                        Spacer()
                        if event.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(12)
                    .background(theme.current.buttonBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .opacity(event.isCompleted ? 1.0 : 0.55)
                }
            }
        }
    }
}

// MARK: - Color from Hex helper

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val         & 0xFF) / 255
        )
    }
}
