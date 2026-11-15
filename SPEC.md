# 試水溫版（Probe）規格

## 目的
正式做「懶人待辦 App」之前，先確認這條路走得通：
1. **雲端編譯**：在 GitHub Actions 的 macOS 機器上產出**未簽名**的 `.ipa`
2. **簽名安裝**：使用者用第三方簽名服務（Flare Store 的憑證），在 iPhone 上重新簽名並安裝
3. **小工具讀資料**：重新簽名後，桌面小工具（Widget）能透過 App Group 讀到主 App 的資料
4. **通知按鈕**：本機通知可以跳出，長按後有「做完了」和「明天再說」兩個按鈕，按了 App 會收到

使用者情況：用 Windows 電腦（沒有 Mac）、不會寫程式；手機是 iPhone 16 Plus，iOS 27。

## 技術選擇（已定案）
- SwiftUI，部署目標 iOS 17.0
- 用 **XcodeGen**（`project.yml`）在 CI 產生 `.xcodeproj`，不手寫、也不提交 `.pbxproj`
- 兩個 target：
  - `LazyTodo`（App），Bundle ID `com.mrhai.lazytodo`
  - `LazyTodoWidget`（Widget Extension），Bundle ID `com.mrhai.lazytodo.widget`
- App Group：`group.com.mrhai.lazytodo`，兩個 target 的 entitlements 都要有
- 資料：用 `UserDefaults(suiteName:)` 存一個 JSON 字串陣列。試水溫版不用 SwiftData

## App 畫面（一頁就好，文字用繁體中文）
1. **輸入框 + 「新增」按鈕**：把文字加到清單裡，存進 App Group，然後呼叫 `WidgetCenter.shared.reloadAllTimelines()`
2. **清單**：顯示已存的項目，可以左滑刪除
3. **診斷區**（給使用者截圖回報用），每一行都顯示 ✅ 或 ❌：
   - App Group 容器：`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 是否為 nil
   - App Group UserDefaults：寫入一個測試值後再讀回來，比對是否相同
   - 實際的 Bundle ID（`Bundle.main.bundleIdentifier`），因為簽名工具可能會改掉它
   - 通知權限狀態
4. **「10 秒後提醒我」按鈕**：先請求通知權限，再排一個 10 秒後的本機通知
   - 通知分類（category）要有兩個動作：「✅ 做完了」、「⏰ 明天再說」
   - App 收到使用者按的動作後，在畫面上顯示「上次收到：做完了／明天再說（時間）」（也存進 UserDefaults）

## 桌面小工具
- 小、中兩種尺寸
- 顯示最新 3 筆項目
- 三種狀態要顯示**不同的文字**，這樣才分得出是哪裡出問題：
  - 讀不到 App Group（容器是 nil）→「❌ 讀不到 App 資料（App Group 失敗）」
  - 讀得到但沒有資料 →「還沒有東西，去 App 裡新增一筆」
  - 有資料 → 列出項目

## GitHub Actions（`.github/workflows/build.yml`）
- 觸發條件：push 到 `main`，以及手動觸發（`workflow_dispatch`）
- `runs-on: macos-latest`，用 runner 上預設的 Xcode
- 步驟：`brew install xcodegen` → `xcodegen generate` → 用 `xcodebuild archive` 編譯，加上 `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
- 從 archive 取出 `LazyTodo.app`（裡面要包含 `PlugIns/LazyTodoWidget.appex`），放進 `Payload/` 資料夾，壓縮成 `LazyTodo-unsigned.ipa`
- 用 `actions/upload-artifact` 上傳這個 ipa
- 要加一個檢查步驟：確認 `.appex` 真的在 `.app/PlugIns` 裡面，不在就讓 workflow 失敗
- entitlements 檔照樣放進 app 和 appex 裡（未簽名也要帶著，簽名工具才讀得到），用 `CODE_SIGN_ENTITLEMENTS` 指定

## 交付物
- `project.yml`、`LazyTodo/`、`LazyTodoWidget/`、entitlements、`.github/workflows/build.yml`、`.gitignore`
- **`使用說明.md`**（繁體中文，寫給完全不會寫程式的人看，一步一步）：
  1. 怎麼看 GitHub Actions 有沒有編譯成功、去哪裡下載 ipa
  2. 用 Flare 的憑證簽名安裝時要注意的地方：如果簽名工具有「保留 App Group／Entitlements」或「不要改 Bundle ID」之類的選項，要怎麼選
  3. 裝好後的檢查清單：診斷區截圖、加一個桌面小工具、按「10 秒後提醒我」再長按通知試兩個按鈕
  4. 要回報給 Claude 的東西：診斷區截圖、小工具截圖、通知按鈕有沒有反應

## 做完的樣子
- 檔案都寫好，`git init` 並 commit 到本機（不 push、不建 GitHub repo，這些等使用者同意再做）
- 這台電腦沒有 Mac，不能本機編譯，所以要仔細自我檢查：`project.yml` 的 target 依賴與內嵌（App 要 embed widget）、Info.plist 的 `NSExtension` 設定、`@main` 只能有一個（Widget 用 `WidgetBundle`）
- 回報：檔案清單，以及哪些地方最可能在第一次 CI 編譯時出錯

## 不要做
- 不做正式版功能（日期解析、今日總覽、分享選單、Siri），那些是試水溫成功之後的事
- 不要碰其他專案資料夾（例如 `shu-timetable`）
