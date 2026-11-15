import SwiftUI
import WidgetKit
import UserNotifications

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var newText = ""
    @State private var items: [String] = []
    @State private var diag = Diagnostics()
    @State private var lastAction = ""
    @State private var reminderMessage = ""

    var body: some View {
        NavigationStack {
            List {
                inputSection
                listSection
                diagnosticsSection
                reminderSection
            }
            .navigationTitle("懶人待辦（試水溫）")
        }
        .onAppear(perform: reloadAll)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reloadAll() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationHandler.didReceiveAction)) { _ in
            reloadAll()
        }
    }

    // MARK: - 1. 輸入

    private var inputSection: some View {
        Section("新增") {
            HStack {
                TextField("想記什麼？", text: $newText)
                    .onSubmit(addItem)
                Button("新增", action: addItem)
                    .buttonStyle(.borderless)
                    .disabled(trimmedText.isEmpty)
            }
        }
    }

    private var trimmedText: String {
        newText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addItem() {
        let text = trimmedText
        guard !text.isEmpty else { return }
        items.insert(text, at: 0)
        SharedStore.saveItems(items)
        WidgetCenter.shared.reloadAllTimelines()
        newText = ""
    }

    // MARK: - 2. 清單

    private var listSection: some View {
        Section("清單（\(items.count) 筆，左滑可刪除）") {
            if items.isEmpty {
                Text("還沒有東西").foregroundStyle(.secondary)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
            }
            .onDelete(perform: deleteItems)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        SharedStore.saveItems(items)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 3. 診斷區

    private var diagnosticsSection: some View {
        Section {
            DiagRow(ok: diag.containerOK, title: "App Group 容器", detail: diag.containerDetail)
            DiagRow(ok: diag.defaultsOK, title: "App Group UserDefaults 寫入讀回", detail: diag.defaultsDetail)
            DiagRow(ok: diag.bundleOK, title: "Bundle ID", detail: diag.bundleID)
            DiagRow(ok: diag.notifOK, title: "通知權限", detail: diag.notifDetail)
            Button("重新檢查", action: reloadAll)
        } header: {
            Text("診斷區（請截圖回報）")
        } footer: {
            Text("App Group：\(SharedStore.appGroupID)\n預期 Bundle ID：\(Diagnostics.expectedBundleID)")
        }
    }

    // MARK: - 4. 通知測試

    private var reminderSection: some View {
        Section("通知測試") {
            Button("10 秒後提醒我") {
                Task {
                    reminderMessage = "處理中…"
                    reminderMessage = await NotificationHandler.shared.scheduleTestReminder()
                    refreshNotificationStatus()
                }
            }
            if !reminderMessage.isEmpty {
                Text(reminderMessage).font(.footnote)
            }
            Text("上次收到：\(lastAction.isEmpty ? "（還沒有）" : lastAction)")
        }
    }

    // MARK: - 重新讀資料

    private func reloadAll() {
        items = SharedStore.loadItems()
        lastAction = SharedStore.loadLastAction()
        runDiagnostics()
    }

    private func runDiagnostics() {
        var d = Diagnostics()

        if let url = SharedStore.containerURL {
            d.containerOK = true
            d.containerDetail = url.path
        } else {
            d.containerOK = false
            d.containerDetail = "nil（簽名時 App Group 沒有帶到）"
        }

        if let defaults = SharedStore.defaults {
            let probe = UUID().uuidString
            defaults.set(probe, forKey: SharedStore.diagProbeKey)
            let readBack = defaults.string(forKey: SharedStore.diagProbeKey)
            d.defaultsOK = (readBack == probe)
            d.defaultsDetail = d.defaultsOK ? "寫入後讀回一致" : "讀回的值不一樣：\(readBack ?? "nil")"
        } else {
            d.defaultsOK = false
            d.defaultsDetail = "UserDefaults(suiteName:) 回傳 nil"
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "（讀不到）"
        d.bundleID = bundleID
        d.bundleOK = (bundleID == Diagnostics.expectedBundleID)

        // 通知權限先保留上一次的結果，等非同步查完再更新
        d.notifOK = diag.notifOK
        d.notifDetail = diag.notifDetail

        diag = d
        refreshNotificationStatus()
    }

    private func refreshNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized:
                diag.notifOK = true; diag.notifDetail = "已允許"
            case .provisional:
                diag.notifOK = true; diag.notifDetail = "暫時允許（安靜送達）"
            case .ephemeral:
                diag.notifOK = true; diag.notifDetail = "暫時允許"
            case .denied:
                diag.notifOK = false; diag.notifDetail = "被拒絕（到 設定 > 通知 > 懶人待辦 打開）"
            case .notDetermined:
                diag.notifOK = false; diag.notifDetail = "還沒問過（按下面「10 秒後提醒我」）"
            @unknown default:
                diag.notifOK = false; diag.notifDetail = "未知狀態"
            }
        }
    }
}

// MARK: - 診斷資料

struct Diagnostics {
    static let expectedBundleID = "com.mrhai.lazytodo"

    var containerOK = false
    var containerDetail = "檢查中…"
    var defaultsOK = false
    var defaultsDetail = "檢查中…"
    var bundleOK = false
    var bundleID = "檢查中…"
    var notifOK = false
    var notifDetail = "檢查中…"
}

struct DiagRow: View {
    let ok: Bool
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(ok ? "✅" : "❌") \(title)")
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
