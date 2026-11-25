# 程序架構與安全

Electron = **Chromium（畫面）+ Node.js（系統能力）**，讓網頁技術做出跨平台桌面程式。VS Code、Slack、Discord 都是 Electron 寫的。

## 三種程序

``` mermaid
flowchart LR
    UI["Renderer<br>React 畫面<br>（無 Node.js 權限）"] -- "invoke" --> API["Preload<br>contextBridge<br>window.electronAPI"] -- "IPC" --> IPC["Main<br>ipcMain.handle<br>（Node.js）"]
    IPC --> DB[("SQLite")]
    IPC --> FS["檔案 / 對話框"]
```

| 程序 | 環境 | 數量 | 負責 |
|------|------|------|------|
| **Main** | Node.js | 1 個 | 建立視窗、選單、存取檔案與資料庫、系統通知 |
| **Renderer** | Chromium（瀏覽器） | 每個視窗 1 個 | 畫面；**不能直接存取 Node.js** |
| **Preload** | 沙箱，介於兩者之間 | 每個視窗 1 個 | 用 `contextBridge` 暴露**經過挑選**的 API 給畫面 |

## 安全設定

``` typescript
new BrowserWindow({
  webPreferences: {
    preload: path.join(__dirname, 'preload.js'),
    contextIsolation: true,      // Preload 與網頁的 JS 環境隔離
    nodeIntegration: false,      // 網頁不能 require('fs')
    // sandbox：Electron 20 之後預設開啟，Preload 也在沙箱中執行
  },
});
```

!!! danger "為什麼不能直接開 nodeIntegration"

    如果畫面能直接用 Node.js，只要出現一個 XSS 漏洞（例如顯示了未跳脫的使用者輸入），攻擊者就能 `require('child_process').exec(...)` **在使用者電腦上執行任意指令**。網頁的漏洞會直接變成作業系統的漏洞。

**縱深防禦清單**

- ✅ `contextIsolation: true`、`nodeIntegration: false`、`sandbox: true`
- ✅ Preload 只暴露**具體的業務方法**（`listMembers`），不暴露通用的 `ipcRenderer.send`
- ✅ 正式版加上 **Content-Security-Policy**，禁止載入外部腳本
- ✅ Main 程序**驗證所有 IPC 參數**，不信任畫面傳來的資料
- ✅ 不載入遠端網址；需要開外部連結時用 `shell.openExternal`

## 型別安全的 IPC

fu-clan 的做法：在 `shared/ipc.ts` 定義一個介面，**同時約束三個地方**：

``` typescript
// shared/ipc.ts：方法名稱就是 IPC channel 名稱
export interface ElectronAPI {
  listMembers(query: MemberQuery): Promise<Page<Member>>;
  createMember(input: MemberInput): Promise<Member>;
  getFamilyTree(memberId: number): Promise<FamilyTree>;
  // …
}
export type IpcChannel = keyof ElectronAPI;
```

``` typescript
// electron/preload.ts：只能 import type，沙箱中無法 require 其他檔案
function invoke<K extends IpcChannel>(channel: K, ...args: Parameters<ElectronAPI[K]>) {
  return ipcRenderer.invoke(channel, ...args) as ReturnType<ElectronAPI[K]>;
}

const electronAPI: ElectronAPI = {
  listMembers: (query) => invoke('listMembers', query),
  createMember: (input) => invoke('createMember', input),
  getFamilyTree: (memberId) => invoke('getFamilyTree', memberId),
};
contextBridge.exposeInMainWorld('electronAPI', electronAPI);
```

``` typescript
// electron/ipc.ts：寫入類操作完成後自動存檔
function handleWrite<K extends IpcChannel>(channel: K, handler: Handler<K>): void {
  register<K>(channel, async (...args) => {
    const result = await handler(...args);
    database.saveDatabase();
    return result;
  });
}

handle('listMembers', database.listMembers);
handleWrite('createMember', database.createMember);
```

!!! tip "好處"

    畫面、Preload、Main 三邊的方法名稱或參數只要對不上，**TypeScript 編譯就會失敗**。這和後端用 OpenAPI 產生前端型別、或 gRPC 用 `.proto` 產生雙方程式碼是同一個概念：**用一份契約約束兩端**。

## 跟 Web 應用的差別

| | Web 應用 | Electron 桌面應用 |
|---|---------|------------------|
| 後端 | 遠端伺服器 + API | **Main 程序**就是後端，透過 IPC 呼叫 |
| 資料 | 伺服器資料庫 | 使用者電腦上的檔案（SQLite） |
| 網路 | 必須連線 | 可以完全離線 |
| 路由 | `BrowserRouter` | `HashRouter`（`file://` 沒有伺服器處理路徑） |
| 更新 | 重新整理就是新版 | 要下載新安裝檔或自動更新 |
| 安全威脅 | XSS 影響網站 | XSS 可能影響**整台電腦** |

## 優點與缺點

=== "優點"

    - **一套程式碼跨三平台**：Windows、macOS、Linux
    - 沿用 Web 技術與生態（React、Ant Design、Vite）
    - 有完整的 Node.js 能力：檔案、系統對話框、原生通知
    - 資料留在本機，**不需要架伺服器**，適合小型組織內部使用

=== "缺點"

    - **安裝檔大、記憶體用量高**：每個程式都帶一份 Chromium（約 100MB 起）
    - 安全模型比 Web 複雜，設定錯誤的代價高
    - 程式碼簽章、公證、自動更新都要額外處理
    - 替代方案 **Tauri**（Rust + 系統 WebView）體積小很多，但生態較新
