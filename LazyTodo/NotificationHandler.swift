import Foundation
import UserNotifications

/// 負責：註冊通知分類（兩個按鈕）、排 10 秒後的提醒、接收使用者按了哪個按鈕。
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    static let categoryID = "TODO_REMINDER"
    static let doneActionID = "DONE"
    static let snoozeActionID = "SNOOZE"

    /// 收到按鈕結果後發給畫面的通知，讓畫面重新讀資料。
    static let didReceiveAction = Notification.Name("LazyTodoDidReceiveAction")

    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let done = UNNotificationAction(identifier: Self.doneActionID, title: "✅ 做完了", options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID, title: "⏰ 明天再說", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [done, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// 先請求權限，再排一個 10 秒後的本機通知。回傳給畫面顯示的結果文字。
    func scheduleTestReminder() async -> String {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                return "❌ 沒有通知權限，請到「設定 > 通知 > 懶人待辦」打開"
            }

            let content = UNMutableNotificationContent()
            content.title = "懶人待辦 測試提醒"
            content.body = "長按這則通知，試試下面的兩個按鈕"
            content.sound = .default
            content.categoryIdentifier = Self.categoryID

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            try await center.add(request)
            return "✅ 已排好，10 秒後會跳通知（可以先回桌面等）"
        } catch {
            return "❌ 排通知失敗：\(error.localizedDescription)"
        }
    }

    // App 開著的時候通知也照樣跳出來。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // 使用者按了通知上的按鈕（或點了通知本身）。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let name: String
        switch response.actionIdentifier {
        case Self.doneActionID:
            name = "做完了"
        case Self.snoozeActionID:
            name = "明天再說"
        case UNNotificationDefaultActionIdentifier:
            name = "點了通知本身（沒有按按鈕）"
        case UNNotificationDismissActionIdentifier:
            name = "把通知滑掉"
        default:
            name = "其他（\(response.actionIdentifier)）"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "M/d HH:mm:ss"
        SharedStore.saveLastAction("\(name)（\(formatter.string(from: Date()))）")

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didReceiveAction, object: nil)
        }
    }
}
