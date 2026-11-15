import SwiftUI
import UIKit

// 整個 App 只有這一個 @main（小工具那邊用的是 WidgetBundle 的 @main，屬於另一個 target）。
@main
struct LazyTodoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 一定要在啟動完成前設定，才收得到使用者按通知按鈕的結果。
        NotificationHandler.shared.setUp()
        return true
    }
}
