// ChallengeShareManager.swift
// ZenithArrows
//
// Feature 7: Challenge a Friend.
//
// Encodes a puzzle configuration into a URL-safe Base64 string that another
// player can paste in to reconstruct the identical level layout.
//
// ## Share Code Format
//
// `SharedChallenge` is JSON-encoded → Base64 with URL-safe substitutions
// (`+` → `-`, `/` → `_`, trailing `=` stripped).  Decoded in reverse.
//
// ## Deep Link URL
// ```
// zenith://challenge?code=<base64>
// ```
// Register the `zenith` URL scheme in Info.plist to handle incoming challenges.
//
// ## Level Reconstruction
//
// `level(from:)` calls `LevelGenerator.generate(seed:...)` with the embedded
// seed, ensuring the friend sees exactly the same arrow layout.
//
// ## Share Sheet
//
// `presentShareSheet(challenge:from:)` presents `UIActivityViewController`
// via the top-most `UIViewController` in the window hierarchy.

import Foundation
import UIKit

// MARK: - Shared Challenge Payload

struct SharedChallenge: Codable {
    let levelID: String
    let seed: Int
    let rows: Int
    let cols: Int
    let arrowCount: Int
    let parMoves: Int
    let difficulty: LevelDifficulty
    let challengerScore: Int?   // optional: sender's best score to beat
    let createdAt: Date

    // URL-safe base64 code
    var shareCode: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromCode(_ code: String) -> SharedChallenge? {
        var padded = code
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = padded.count % 4
        if remainder != 0 { padded += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: padded) else { return nil }
        return try? JSONDecoder().decode(SharedChallenge.self, from: data)
    }
}

// MARK: - ChallengeShareManager

final class ChallengeShareManager {

    static let shared = ChallengeShareManager()
    private let generator = LevelGenerator()

    private init() {}

    // MARK: - Create Challenge

    func createChallenge(
        from level: LevelDefinition,
        challengerScore: Int? = nil
    ) -> SharedChallenge {
        let seed = abs(level.id.hashValue) ^ Int(Date().timeIntervalSince1970) % 10000
        return SharedChallenge(
            levelID: level.id,
            seed: seed,
            rows: level.gridRows,
            cols: level.gridCols,
            arrowCount: level.arrows.count,
            parMoves: level.parMoves,
            difficulty: level.difficulty,
            challengerScore: challengerScore,
            createdAt: Date()
        )
    }

    // MARK: - Reconstruct Level

    func level(from challenge: SharedChallenge) -> LevelDefinition? {
        let base = generator.generate(
            seed: challenge.seed,
            rows: challenge.rows,
            cols: challenge.cols,
            arrowCount: challenge.arrowCount,
            difficulty: challenge.difficulty,
            worldID: 0
        )
        guard var level = base else { return nil }
        // Patch metadata to reflect the challenge context
        return LevelDefinition(
            id: "challenge_\(challenge.levelID)",
            worldID: 0,
            index: 0,
            gridRows: level.gridRows,
            gridCols: level.gridCols,
            arrows: level.arrows,
            obstacles: level.obstacles,
            difficulty: level.difficulty,
            parMoves: challenge.parMoves,
            parTime: 120,
            diagonalsEnabled: level.diagonalsEnabled,
            title: "Friend Challenge"
        )
    }

    // MARK: - Share Sheet

    func presentShareSheet(challenge: SharedChallenge, from viewController: UIViewController? = nil) {
        let code = challenge.shareCode
        let scoreText = challenge.challengerScore.map { "Beat my score of \($0)! " } ?? ""
        let message = "\(scoreText)Try this ZenithArrows puzzle! Code: \(code)"

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        // Find top presenter
        let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController

        presenter?.present(activityVC, animated: true)
    }

    // MARK: - Deep Link URL

    func deepLinkURL(for challenge: SharedChallenge) -> URL? {
        var components = URLComponents()
        components.scheme = "zenith"
        components.host = "challenge"
        components.queryItems = [URLQueryItem(name: "code", value: challenge.shareCode)]
        return components.url
    }
}
