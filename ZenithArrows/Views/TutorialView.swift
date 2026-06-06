// TutorialView.swift
// ZenithArrows
// First 5 levels are wrapped in this guided tutorial overlay.

import SwiftUI

struct TutorialStep {
    let message: String
    let highlightPosition: GridPosition?
    let arrowSystemImage: String?
}

struct TutorialOverlayView: View {

    let step: TutorialStep
    var onDismiss: () -> Void

    @StateObject private var theme = ThemeManager.shared
    @State private var visible = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                if let img = step.arrowSystemImage {
                    Image(systemName: img)
                        .font(.system(size: 32))
                        .foregroundStyle(theme.current.accentColor)
                }

                Text(step.message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.current.textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button("Got it!") { onDismiss() }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(theme.current.accentColor, in: Capsule())
                    .buttonStyle(.plain)
            }
            .padding(24)
            .background(theme.current.hudBackground, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.4), radius: 20)
            .scaleEffect(visible ? 1 : 0.85)
            .opacity(visible ? 1 : 0)

            Spacer().frame(height: 50)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                visible = true
            }
        }
    }
}

// MARK: - Tutorial Steps Definition

let tutorialSteps: [TutorialStep] = [
    TutorialStep(
        message: "Welcome to ZenithArrows!\nEach arrow can slide out in the direction it points — but only if the path is completely clear.",
        highlightPosition: nil,
        arrowSystemImage: "arrow.up"
    ),
    TutorialStep(
        message: "Tap a glowing arrow to slide it off the board. Clearing one arrow may unblock others!",
        highlightPosition: nil,
        arrowSystemImage: "hand.tap"
    ),
    TutorialStep(
        message: "Think ahead! Some arrows can only move after you remove the ones blocking their path.",
        highlightPosition: nil,
        arrowSystemImage: "brain.head.profile"
    ),
    TutorialStep(
        message: "You have 3 lives. Tapping a blocked arrow costs a life. Use hints if you're stuck!",
        highlightPosition: nil,
        arrowSystemImage: "heart.fill"
    ),
    TutorialStep(
        message: "Clear all arrows from the grid to win. Good luck!",
        highlightPosition: nil,
        arrowSystemImage: "star.fill"
    )
]
