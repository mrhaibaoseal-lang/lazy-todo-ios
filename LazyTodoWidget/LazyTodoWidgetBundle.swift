import SwiftUI
import WidgetKit

// 小工具 target 唯一的 @main。
@main
struct LazyTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentItemsWidget()
    }
}

// MARK: - 資料

enum WidgetState {
    case noAppGroup          // 容器是 nil
    case empty               // 讀得到但沒資料
    case items([String])     // 有資料（最多 3 筆）

    static func current() -> WidgetState {
        guard SharedStore.containerURL != nil else { return .noAppGroup }
        let items = SharedStore.loadItems()
        return items.isEmpty ? .empty : .items(Array(items.prefix(3)))
    }
}

struct RecentItemsEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

struct RecentItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentItemsEntry {
        RecentItemsEntry(date: Date(), state: .items(["交報告", "還朋友錢", "看 TronClass"]))
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentItemsEntry) -> Void) {
        completion(RecentItemsEntry(date: Date(), state: .current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentItemsEntry>) -> Void) {
        let now = Date()
        let entry = RecentItemsEntry(date: now, state: .current())
        let next = now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 畫面

struct RecentItemsView: View {
    let entry: RecentItemsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("懶人待辦")
                .font(.headline)

            switch entry.state {
            case .noAppGroup:
                Text("❌ 讀不到 App 資料（App Group 失敗）")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .empty:
                Text("還沒有東西，去 App 裡新增一筆")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .items(let items):
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RecentItemsWidget: Widget {
    let kind = "RecentItemsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentItemsProvider()) { entry in
            RecentItemsView(entry: entry)
        }
        .configurationDisplayName("懶人待辦")
        .description("顯示最新 3 筆待辦")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
