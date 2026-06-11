// TrailEffectView.swift
// ZenithArrows
// Feature 11: Arrow Slide Trail — particle trail overlay displayed
// over the SpriteKit canvas as an arrow slides out.

import SwiftUI

// MARK: - Trail Particle

struct TrailParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var scale: CGFloat = 1.0
    var color: Color
}

// MARK: - TrailEffectViewModel

@MainActor
final class TrailEffectViewModel: ObservableObject {

    @Published private(set) var particles: [TrailParticle] = []

    private var cleanupTask: Task<Void, Never>? = nil

    /// Spawn a trail along the given cell path.
    /// `cellCenters` — the CGPoints (in screen coordinates) of each traversed cell.
    func spawnTrail(along cellCenters: [CGPoint], color: Color) {
        guard !cellCenters.isEmpty else { return }

        let newParticles = cellCenters.enumerated().map { (i, pt) in
            TrailParticle(
                position: pt,
                opacity: 1.0 - Double(i) * (0.7 / Double(max(cellCenters.count, 1))),
                scale: 1.0 - CGFloat(i) * 0.08,
                color: color
            )
        }

        particles.append(contentsOf: newParticles)
        scheduleCleanup()
    }

    func clear() {
        cleanupTask?.cancel()
        particles.removeAll()
    }

    private func scheduleCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { @MainActor in
            // Animate fade-out after 0.4 s
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                for i in self.particles.indices {
                    self.particles[i].opacity = 0
                    self.particles[i].scale = 0.3
                }
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self.particles.removeAll()
        }
    }
}

// MARK: - TrailEffectView

struct TrailEffectView: View {
    @ObservedObject var viewModel: TrailEffectViewModel

    var body: some View {
        ZStack {
            ForEach(viewModel.particles) { particle in
                Circle()
                    .fill(particle.color.opacity(particle.opacity * 0.65))
                    .frame(width: 18 * particle.scale, height: 18 * particle.scale)
                    .position(particle.position)
                    .blur(radius: 3)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
