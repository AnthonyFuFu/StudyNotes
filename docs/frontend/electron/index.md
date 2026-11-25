---
icon: lucide/app-window
---

# Electron 桌面應用

用網頁技術做跨平台桌面程式。重點在 Main / Renderer / Preload 三種程序的分工、IPC 與安全設定，以及本機資料儲存與三平台打包。

**核心技術**：Main / Renderer / Preload / contextBridge / IPC / sql.js / electron-builder / GitHub Actions matrix

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Electron 桌面應用"])
    c0["01 · 程序架構與安全"]
    R --> c0
    p0("・三種程序<br>・安全設定<br>・型別安全的 IPC<br>・跟 Web 應用的差別")
    c0 --- p0
    c1["02 · 資料儲存、打包與 CI"]
    R --> c1
    p1("・本機資料庫：sql.js<br>・分層與共用規則<br>・Excel 匯入匯出<br>・打包：electron-builder<br>・CI：GitHub Actions")
    c1 --- p1
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1 chapter
    class p0,p1 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 程序架構與安全](architecture.md)__

    ---

    三種程序 · 安全設定 · 型別安全的 IPC · 跟 Web 應用的差別

-   __[02 · 資料儲存、打包與 CI](engineering.md)__

    ---

    本機資料庫：sql.js · 分層與共用規則 · Excel 匯入匯出 · 打包：electron-builder …

</div>

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 一套程式碼跨 Windows、macOS、Linux | 每個程式都帶一份 Chromium，安裝檔大、記憶體用量高 |
| 沿用 React、Ant Design、Vite 等 Web 生態 | 安全模型複雜，設定錯誤代價高 |
| 有完整的 Node.js 能力：檔案、對話框、通知 | 程式碼簽章、公證、自動更新要額外處理 |
| 資料留在本機，不需要伺服器 | 替代方案 Tauri 體積更小，但生態較新 |
