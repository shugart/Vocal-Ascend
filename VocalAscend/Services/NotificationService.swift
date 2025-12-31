import Foundation
import UserNotifications
import Combine

/// Manages local notifications for daily training reminders
final class NotificationService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isAuthorized = false
    @Published private(set) var pendingReminders: [UNNotificationRequest] = []

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()
    private let reminderIdentifierPrefix = "vocal_ascend_reminder_"

    // MARK: - Initialization

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await MainActor.run {
                isAuthorized = granted
            }

            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Daily Reminder

    /// Schedule a daily training reminder
    func scheduleDailyReminder(at hour: Int, minute: Int = 0) async {
        // First, remove any existing reminders
        await cancelAllReminders()

        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }

        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Train!"
        content.body = randomReminderMessage()
        content.sound = .default
        content.badge = 1

        // Create a daily trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        // Create the request
        let request = UNNotificationRequest(
            identifier: "\(reminderIdentifierPrefix)daily",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Daily reminder scheduled for \(hour):\(String(format: "%02d", minute))")
            await refreshPendingReminders()
        } catch {
            print("Failed to schedule reminder: \(error)")
        }
    }

    /// Schedule a reminder for tomorrow (one-time)
    func scheduleReminderForTomorrow(at hour: Int, message: String? = nil) async {
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }

        let content = UNMutableNotificationContent()
        content.title = "Recovery Day Reminder"
        content.body = message ?? "Your voice has rested. Ready for a light session today?"
        content.sound = .default

        // Calculate tomorrow at the specified hour
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else { return }

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(reminderIdentifierPrefix)recovery_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            print("Recovery reminder scheduled for tomorrow")
        } catch {
            print("Failed to schedule recovery reminder: \(error)")
        }
    }

    /// Cancel all scheduled reminders
    func cancelAllReminders() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let reminderIds = requests
            .filter { $0.identifier.hasPrefix(reminderIdentifierPrefix) }
            .map { $0.identifier }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: reminderIds)

        await MainActor.run {
            pendingReminders = []
        }
    }

    /// Cancel the daily reminder specifically
    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["\(reminderIdentifierPrefix)daily"]
        )
    }

    /// Refresh the list of pending reminders
    func refreshPendingReminders() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let reminders = requests.filter { $0.identifier.hasPrefix(reminderIdentifierPrefix) }

        await MainActor.run {
            pendingReminders = reminders
        }
    }

    /// Clear the badge count
    func clearBadge() async {
        await MainActor.run {
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    // MARK: - Motivational Messages

    private func randomReminderMessage() -> String {
        let messages = [
            "Your voice is waiting! Just 20 minutes of focused practice today.",
            "Time for your vocal workout. Consistency is the key to progress!",
            "Ready to hit those notes? Let's make today's session count!",
            "Your daily training session awaits. Small steps, big progress!",
            "Don't forget to warm up your voice today!",
            "A quick session now builds your range for tomorrow!",
            "Your voice needs regular exercise. Let's train!",
            "Progress happens one session at a time. Ready?",
            "Your personalized workout is ready. Let's go!",
            "Time to invest in your voice. Training session awaits!"
        ]
        return messages.randomElement() ?? messages[0]
    }

    // MARK: - Streak Notifications

    /// Schedule a streak reminder if user misses a day
    func scheduleStreakReminder(currentStreak: Int) async {
        guard currentStreak > 0, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak!"
        content.body = "You have a \(currentStreak)-day streak going. Train today to keep it alive!"
        content.sound = .default

        // Trigger in the evening if they haven't trained
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(reminderIdentifierPrefix)streak_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule streak reminder: \(error)")
        }
    }

    /// Cancel streak reminders (call when user completes a session)
    func cancelStreakReminders() {
        Task {
            let requests = await notificationCenter.pendingNotificationRequests()
            let streakIds = requests
                .filter { $0.identifier.contains("streak_") }
                .map { $0.identifier }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: streakIds)
        }
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner and sound even when app is open
        return [.banner, .sound]
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Clear badge when user taps notification
        await NotificationService.shared.clearBadge()

        // You could post a notification here to navigate to the Train screen
        NotificationCenter.default.post(name: .didTapTrainingReminder, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapTrainingReminder = Notification.Name("didTapTrainingReminder")
}
