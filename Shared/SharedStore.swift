import Foundation

/// App 和小工具共用的資料存取（兩個 target 都會編譯這個檔案）。
enum SharedStore {
    static let appGroupID = "group.com.mrhai.lazytodo"

    static let itemsKey = "items"                 // JSON 字串陣列，最新的在最前面
    static let lastActionKey = "lastNotificationAction"
    static let diagProbeKey = "diagProbe"

    /// App Group 容器；簽名沒帶到 App Group 時會是 nil。
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func loadItems() -> [String] {
        guard let text = defaults?.string(forKey: itemsKey),
              let data = text.data(using: .utf8),
              let items = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return items
    }

    static func saveItems(_ items: [String]) {
        guard let data = try? JSONEncoder().encode(items),
              let text = String(data: data, encoding: .utf8)
        else { return }
        defaults?.set(text, forKey: itemsKey)
    }

    static func loadLastAction() -> String {
        defaults?.string(forKey: lastActionKey) ?? ""
    }

    static func saveLastAction(_ text: String) {
        defaults?.set(text, forKey: lastActionKey)
    }
}
