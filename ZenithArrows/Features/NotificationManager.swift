// NotificationManager.swift
// ZenithArrows
//
// Feature 20: Local Push Notifications.
//
// Schedules three repeating `UNCalendarNotificationTrigger` notifications:
//
// | Notification     | Schedule          | Purpose                     |
// |------------------|-------------------|-----------------------------||
// | dailyChallenge   | 9:00 AM daily     | Remind player to solve today |
// | weeklyChallenge  | Monday 10:00 AM   | New weekly puzzle available  |
// | streakReminder   | 8:00 PM daily     | Don't break the streak       |
//
// ## Permission Flow
//
// `requestAuthorization()` async — returns `Bool` indicating grant.
// Called once on first `HomeView.onAppear`; if denied, the Settings sheet
// shows an alert offering a deeplink to iOS Settings.
//
// ## Badge Management
//
// `clearBadge()` resets the app icon badge count to 0; called on every
// `HomeView.onAppear` via `applicationDidBecomeActive`.
//
// ## Identifiers
//
// All identifiers are namespaced under `ZenithNotification` enum:
// `.dailyChallenge` = `"zenith.daily"`
// `.weeklyChallenge` = `"zenith.weekly"`
// `.streakReminder`  = `"zenith.streak"`

import Foundation
import UserNotifications

// MARK: - Notification Category IDs

enum ZenithNotification: String {
    case dailyChallenge   = "zenith.daily"
    case weeklyChallenge  = "zenith.weekly"
    case streakReminder   = "zenith.streak"
}

// MARK: - NotificationManager

final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted { await scheduleAll() }
            return granted
        } catch {
            return false
        }
    }

    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule All

    func scheduleAll() async {
        await scheduleDailyChallenge()
        await scheduleWeeklyChallenge()
        await scheduleStreakReminder()
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Daily Challenge (9:00 AM every day)

    func scheduleDailyChallenge() async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "🎯 Daily Challenge Ready!"
        content.body = "A fresh ZenithArrows puzzle is waiting. Keep your streak alive!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = ZenithNotification.dailyChallenge.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ZenithNotification.dailyChallenge.rawValue,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Weekly Challenge Reset (Monday 10:00 AM)

    func scheduleWeeklyChallenge() async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "🏆 New Weekly Challenge!"
        content.body = "This week's hard puzzle just dropped. Can you top the leaderboard?"
        content.sound = .default
        content.categoryIdentifier = ZenithNotification.weeklyChallenge.rawValue

        var dateComponents = DateComponents()
        dateComponents.weekday = 2  // Monday
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ZenithNotification.weeklyChallenge.rawValue,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Streak Reminder (8:00 PM if not played today)

    func scheduleStreakReminder() async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "🔥 Don't Break Your Streak!"
        content.body = "Play today's puzzle before midnight to keep your streak going."
        content.sound = .default
        content.categoryIdentifier = ZenithNotification.streakReminder.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ZenithNotification.streakReminder.rawValue,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel Specific

    func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [ZenithNotification.streakReminder.rawValue]
        )
    }

    // MARK: - Badge Clear

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // MARK: - Pending Count (for debugging / settings display)

    func pendingCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
}
