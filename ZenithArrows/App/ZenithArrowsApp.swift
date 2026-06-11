// ZenithArrowsApp.swift
// ZenithArrows
//
// App entry point and delegate.
//
// Responsibilities:
//  - Declares `@main` SwiftUI App struct.
//  - Forces dark-mode presentation for consistent theme rendering.
//  - `AppDelegate` pre-warms heavyweight singletons (`LevelManager`,
//    `ProgressManager`) on a background task so the first `HomeView` frame
//    does not block the main thread.
//  - On `applicationDidBecomeActive`: restarts ambient background music if
//    the user had music enabled before backgrounding.

import SwiftUI

@main
struct ZenithArrowsApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Pre-warm singletons on background thread to avoid first-frame stutter
        Task.detached(priority: .background) {
            _ = await LevelManager.shared
            _ = await ProgressManager.shared
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume music if user returns from background
        Task { @MainActor in
            if AudioManager.shared.isMusicEnabled {
                AudioManager.shared.playMusic(track: "music_ambient")
            }
        }
    }
}
