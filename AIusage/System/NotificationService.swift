import Foundation
import UserNotifications

actor NotificationService {
    private var requestedAuthorization = false

    func requestAuthorizationIfNeeded() async {
        guard !requestedAuthorization else { return }
        requestedAuthorization = true
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            // Notification permission is optional for the meter.
        }
    }

    func deliverLowQuotaNotification(remainingPercentText: String, resetText: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Codex 额度偏低"
        content.body = "5 小时窗口剩余 \(remainingPercentText)，\(resetText)。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex-meter-low-quota",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
