// HapticManager.swift
// ZenithArrows
//
// Wraps Core Haptics for premium tactile feedback with graceful degradation.
//
// ## Feedback Patterns
//
// | Method         | Intensity | Sharpness | Duration | Use Case                  |
// |----------------|-----------|-----------|----------|---------------------------|
// | arrowTap()     | 0.6       | 0.8       | 80 ms    | Successful arrow tap      |
// | wrongTap()     | 0.9       | 0.3       | 150 ms   | Invalid tap (dull thud)   |
// | levelComplete()| escalating triple pulse         | Win celebration           |
// | levelFailed()  | 1.0       | 0.1       | 400 ms   | Long dull rumble          |
// | buttonTap()    | UIImpactFeedbackGenerator light  | UI navigation             |
// | starEarned()   | 0.75      | 1.0       | 100 ms   | Per-star animation (F.12) |
//
// ## Degradation
//
// Falls back to `UIImpactFeedbackGenerator` if `CHHapticEngine` is unavailable
// (e.g., iPad or older iPhone without Core Haptics support).

import CoreHaptics
import UIKit

@MainActor
final class HapticManager {

    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "zenith_haptics_enabled")
    }

    private init() {
        // Default: haptics on
        if !UserDefaults.standard.contains(key: "zenith_haptics_enabled") {
            UserDefaults.standard.set(true, forKey: "zenith_haptics_enabled")
        }
        prepareEngine()
    }

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
        } catch {
            // Haptics unavailable — silent degradation
        }
    }

    // MARK: - Feedback Events

    func arrowTap() {
        guard isEnabled else { return }
        play(intensity: 0.6, sharpness: 0.8, duration: 0.08)
    }

    func wrongTap() {
        guard isEnabled else { return }
        play(intensity: 0.9, sharpness: 0.3, duration: 0.15)
    }

    func levelComplete() {
        guard isEnabled else { return }
        // Escalating triple pulse
        playPattern([
            (intensity: 0.5, sharpness: 0.9, time: 0.0,  duration: 0.06),
            (intensity: 0.7, sharpness: 0.9, time: 0.10, duration: 0.08),
            (intensity: 1.0, sharpness: 1.0, time: 0.22, duration: 0.12)
        ])
    }

    func levelFailed() {
        guard isEnabled else { return }
        play(intensity: 1.0, sharpness: 0.1, duration: 0.4)
    }

    func buttonTap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Feature 12 – per-star earned pulse
    func starEarned() {
        guard isEnabled else { return }
        play(intensity: 0.75, sharpness: 1.0, duration: 0.1)
    }

    // MARK: - Private Helpers

    private func play(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        do {
            let intParam  = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let sharpParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [intParam, sharpParam],
                                      relativeTime: 0,
                                      duration: duration)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { /* silent */ }
    }

    private func playPattern(_ steps: [(intensity: Float, sharpness: Float,
                                         time: TimeInterval, duration: TimeInterval)]) {
        guard let engine else { return }
        do {
            let events = steps.map { s -> CHHapticEvent in
                let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: s.intensity)
                let sh = CHHapticEventParameter(parameterID: .hapticSharpness, value: s.sharpness)
                return CHHapticEvent(eventType: .hapticContinuous,
                                     parameters: [i, sh],
                                     relativeTime: s.time,
                                     duration: s.duration)
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { /* silent */ }
    }
}

private extension UserDefaults {
    func contains(key: String) -> Bool { object(forKey: key) != nil }
}
