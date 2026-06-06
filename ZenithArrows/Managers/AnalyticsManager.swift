// AnalyticsManager.swift
// ZenithArrows
// Lightweight, privacy-first local analytics.
// Replace with Firebase/Amplitude only if user consents; by default stays local.

import Foundation

enum AnalyticsEvent {
    case levelStarted(levelID: String)
    case levelCompleted(levelID: String, stars: Int, moves: Int, time: TimeInterval)
    case levelFailed(levelID: String, moves: Int)
    case hintUsed(levelID: String)
    case themeChanged(to: String)
    case iapInitiated(productID: String)
}

final class AnalyticsManager {

    static let shared = AnalyticsManager()
    private var buffer: [[String: Any]] = []
    private let bufferKey = "zenith_analytics_buffer"

    private init() { loadBuffer() }

    func log(_ event: AnalyticsEvent) {
        var dict: [String: Any] = ["ts": ISO8601DateFormatter().string(from: Date())]
        switch event {
        case .levelStarted(let id):
            dict["event"] = "level_started"
            dict["level_id"] = id
        case .levelCompleted(let id, let stars, let moves, let time):
            dict["event"] = "level_completed"
            dict["level_id"] = id
            dict["stars"] = stars
            dict["moves"] = moves
            dict["time"] = time
        case .levelFailed(let id, let moves):
            dict["event"] = "level_failed"
            dict["level_id"] = id
            dict["moves"] = moves
        case .hintUsed(let id):
            dict["event"] = "hint_used"
            dict["level_id"] = id
        case .themeChanged(let theme):
            dict["event"] = "theme_changed"
            dict["theme"] = theme
        case .iapInitiated(let pid):
            dict["event"] = "iap_initiated"
            dict["product_id"] = pid
        }
        buffer.append(dict)
        if buffer.count >= 50 { flush() }
        saveBuffer()
    }

    /// In a real app, flush sends events to a backend.
    /// Here we just clear the buffer (no network calls = privacy safe by default).
    func flush() {
        buffer.removeAll()
        saveBuffer()
    }

    private func saveBuffer() {
        if let data = try? JSONSerialization.data(withJSONObject: buffer) {
            UserDefaults.standard.set(data, forKey: bufferKey)
        }
    }

    private func loadBuffer() {
        guard let data = UserDefaults.standard.data(forKey: bufferKey),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        buffer = arr
    }
}
