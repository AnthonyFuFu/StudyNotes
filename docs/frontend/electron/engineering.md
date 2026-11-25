# 資料儲存、打包與 CI

!!! abstract "專案：fu-clan-management-system"

    宗親名冊、世系圖、活動行事曆、會費與收支管理的桌面程式。**資料完全留在使用者自己的電腦裡**，不需要網路，也不需要架設伺服器。

## 本機資料庫：sql.js

| 方案 | 說明 | 取捨 |
|------|------|------|
| `better-sqlite3` | 原生 SQLite 綁定，效能最好 | 要針對 Electron 版本**重新編譯原生模組**，跨平台打包麻煩 |
| **sql.js**（我的選擇） | SQLite 編譯成 **WebAssembly** | ✅ 不需要原生編譯；❌ 資料庫在記憶體中，要自己定期寫回檔案 |
| IndexedDB | 瀏覽器內建 | 不是 SQL，查詢與匯出不方便 |

**sql.js 的運作方式**

``` mermaid
flowchart LR
    F[("clan.db 檔案")] -- "啟動時整份讀入" --> MEM["記憶體中的 SQLite"]
    MEM -- "寫入類 IPC 完成後<br>saveDatabase()" --> F
    F -- "每天自動備份" --> BK[("backups/")]
```

- 啟動時把整個 `.db` 檔載入記憶體，查詢都在記憶體中進行，速度很快
- 所有**寫入類**的 IPC 以 `handleWrite` 註冊，完成後立刻存檔，避免程式異常關閉時遺失資料
- 每天自動備份一次，也提供手動備份與還原

## 分層與共用規則

``` text
shared/          # 主程序與畫面共用：型別、IPC 介面、業務規則常數
electron/
  ├── main.ts      # 進入點：開啟資料庫、自動備份、建立視窗
  ├── ipc.ts       # 註冊所有 IPC handler（錯誤寫入記錄檔）
  ├── preload.ts   # contextBridge
  ├── services/    # 檔案、對話框、Excel、備份
  └── db/          # SQL 查詢與業務規則
src/             # React 畫面
```

!!! tip "規則只寫一份"

    例如「活動提醒天數內、今天已結束不提醒」這條規則放在 `shared/events.ts`，主程序（決定要不要跳通知）和畫面（顯示提醒列表）都 import 同一份，不會出現兩邊判斷不一致。

## Excel 匯入匯出

使用 SheetJS（`xlsx`）。產生與解析 Excel 的程式**不碰對話框與檔案系統**，只處理資料轉換，因此可以單獨寫單元測試；開檔、存檔由 `services/dialogs.ts` 負責。

## 打包：electron-builder

``` bash
npm run electron:build      # build（Vite）→ build:electron（tsc）→ electron-builder
```

| 平台 | 產物 | 注意 |
|------|------|------|
| Windows | `.exe`（NSIS 安裝精靈） | 沒有程式碼簽章時 SmartScreen 會警告 |
| macOS | `.dmg` | 沒有公證（notarization）時需右鍵 →「打開」 |
| Linux | `.AppImage` | `chmod +x` 後直接執行 |

安裝檔已包含完整執行環境，**使用者不需要安裝 Node.js**。

## CI：GitHub Actions

``` mermaid
flowchart LR
    A["npm ci"] --> B["ESLint"] --> C["Prettier"] --> D["型別檢查"] --> E["Vitest"]
```

``` mermaid
flowchart LR
    E["檢查通過"] --> W["Windows .exe"] & M["macOS .dmg"] & L["Linux .AppImage"]
    W & M & L --> U["上傳 Artifact<br>保留 30 天"]
```

- 檢查與測試在 Ubuntu 上執行一次
- 打包用 **matrix** 在三個作業系統上**同時**進行，因為 electron-builder 只能可靠地打包目前作業系統的格式
- push 到 `master` 或手動觸發時保存安裝檔；PR 只驗證能打包

## 學到的事

| 問題 | 解法 |
|------|------|
| `BrowserRouter` 在正式版找不到頁面 | 改用 `HashRouter` |
| 原生模組跨平台編譯失敗 | 改用 WebAssembly 版的 sql.js |
| 主程序錯誤看不到 | `ipc.ts` 統一捕捉錯誤寫進 `logs/main.log`，畫面只顯示整理過的訊息 |
| 畫面與主程序型別不一致 | `shared/` 共用型別，`tsconfig` 的 path alias（`@shared/*`）兩邊都能 import |
