# Study Notes

全端工程師的深度學習筆記網站，以 [zensical](https://zensical.org/) 建立，內容以 Markdown 撰寫。

筆記系統性整理核心知識體系，並搭配實際專案的實作，共 **7 大分類、26 個主題、126 個章節**：

| 分類 | 主題 |
|------|------|
| Java 核心 | Java 新特性 / JVM 深度原理 / Java 並發 |
| 後端框架 | Spring Boot（MVC）/ Spring WebFlux / Spring Cloud 微服務 / ASP.NET Core |
| 前端與桌面 | 前端基礎原理 / 伺服器端模板（Thymeleaf、Razor）/ Vue / React / Angular / Electron 桌面應用 |
| 資料與訊息 | MySQL 深度優化 / Redis 深度 / Elasticsearch / 訊息佇列（Kafka、RabbitMQ） |
| 架構設計 | 系統設計 / 設計模式 / API 設計與通訊協議 |
| 網路與資安 | 網路基礎 / 資安 |
| 工程實踐 | 測試 / CI/CD 與 DevOps（含 Harbor、Argo CD）/ AWS 雲端服務 / 監控與可觀測性 |

框架類主題都依照「原理 → 優缺點 → 我的實作」撰寫，實作內容來自以下專案：holidayDessert、holiday_dessert_vue、stock-observation、microservicecloud、chineseArtwork、chinese_artwork_angular、fu-clan-management-system。

## 快速開始

### 需要先安裝

- Python 3.11 或更新版本
- Git

### 1. 複製專案

```bash
git clone -b master https://github.com/AnthonyFuFu/StudyNotes.git
cd StudyNotes
```

### 2. 建立並啟用 Python 虛擬環境

#### Windows PowerShell

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

如果 PowerShell 阻止啟用虛擬環境，請執行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

#### Linux 或 macOS

```bash
python3.11 -m venv .venv
source .venv/bin/activate
```

### 3. 安裝專案所需套件

確認虛擬環境已啟用，再執行：

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 4. 啟動本機預覽網站

```bash
python -m zensical serve
```

瀏覽器開啟 <http://localhost:8000>，修改 `docs/` 內的檔案後頁面會自動重新整理。

## 專案結構

```text
StudyNotes/
├── zensical.toml            # 網站設定：nav、主題、搜尋、Markdown 擴充
├── requirements.txt
├── Dockerfile               # 建置靜態網站並以 nginx 提供服務
├── nginx-custom.conf
├── .github/workflows/CI.yml # push 到 master 時部署到 GitHub Pages
└── docs/
    ├── index.md             # 首頁（知識地圖）
    ├── about.md             # 關於我
    ├── assets/images/       # 圖片
    └── <分類>/              # java、backend、frontend、data、architecture、network-security、engineering
        ├── index.md         # 分類首頁（主題卡片）
        └── <主題>/
            ├── index.md     # 主題首頁（學習地圖、章節導覽、重點速覽、核心要點總結）
            └── <章節>.md    # 一個章節一頁
```

## 網站架構：nav、sidebar、main

網站分成三層，新增內容時請依照同樣的層級放置：

| 層級 | 對應 | 範例 |
|------|------|------|
| **nav**（上方分頁） | 分類資料夾 | `Java 核心` → `docs/java/` |
| **sidebar**（左側導覽） | 主題資料夾與章節檔案 | `JVM 深度原理` → `docs/java/jvm/`，其下每個章節一頁 |
| **main + 右側目錄** | 章節頁內的 `##` / `###` 標題 | `gc.md` 裡的「G1 收集器」、「ZGC」 |

`zensical.toml` 已開啟 `navigation.tabs`（分類顯示在上方分頁）、`navigation.indexes`（資料夾的 `index.md` 作為該區段首頁）、`navigation.prune`（側欄只展開目前所在的主題，其他主題點了才展開）與 `toc.follow`（右側目錄跟隨捲動）。

搜尋框右邊的 GitHub 連結來自 `repo_url` / `repo_name` 設定。

## 編輯文件

### 新增章節

1. 在主題資料夾中新增 `.md` 檔，檔名用英文小寫加連字號，例如 `docs/java/jvm/jit.md`。
2. 第一行寫 `# 章節標題`，內文從 `##` 開始。
3. 在 `zensical.toml` 的 `nav` 中，把頁面加到對應主題底下：

    ```toml
    { "JVM 深度原理" = [
      "java/jvm/index.md",
      { "JVM 整體架構" = "java/jvm/architecture.md" },
      { "JIT 編譯" = "java/jvm/jit.md" },
    ] },
    ```

4. 在主題首頁 `index.md` 的「章節導覽」卡片中加上新章節。

> 頁面沒有列在 `nav` 裡就不會出現在網站導覽中。nav 的路徑以 `docs/` 為起點。

### 新增主題

1. 在分類資料夾下建立主題資料夾，並新增 `index.md`。
2. `index.md` 開頭用 front matter 設定 sidebar 圖示（使用 [Lucide](https://lucide.dev/icons/) 圖示名稱）：

    ```markdown
    ---
    icon: lucide/cpu
    ---

    # 主題名稱
    ```

3. 主題首頁依序放：簡介與核心技術 → `## 學習地圖` → `## 章節導覽`（卡片）→ `## 重點速覽` → `## 核心要點總結`。學習地圖用由左到右的樹狀圖（`flowchart LR`）：主題 → 章節 → 一個條列重點的方框，格式可參考 `docs/java/jvm/index.md`。
4. 在 `zensical.toml` 的 `nav` 加入主題區塊，並在分類首頁加上主題卡片。

## 書寫規則

- **標題**：每頁只有一個 `#`；章節內用 `##`、`###`，它們會出現在右側目錄。標題不加裝飾用的 emoji。
- **本章重點**：每個章節的 `#` 標題下方放一個 `!!! abstract "本章重點"`，用兩三句話說明這章解決什麼問題、讀完能掌握什麼。
- **程式範例**：內文的程式碼盡量控制在 60 行以內。多個類別或多個步驟就拆成分頁（`=== "標題"`）；必須保留的完整版放進 `??? example "完整程式碼"`。
- **表格欄名要具體**：例如「Header / 用途」、「Extra 值 / 意義」，不要用「項目 / 說明」。
- **說明文字用 Markdown，不要塞進 code block**：條列用清單，對照用表格，code block 只放程式碼、設定檔、指令。
- **程式碼**：一律標示語言，例如 ` ```java `、` ```yaml `、` ```bash `。
- **波浪號**：網站啟用了 `pymdownx.tilde`，`~文字~` 會變成下標。表示範圍時請寫成 `3\~4`。

### 常用元件

```markdown
!!! warning "標題"

    提示框，種類有 note / info / tip / success / warning / danger / quote。

??? question "可以折疊的問題"

    點開才看得到的答案，適合面試題。

=== "分頁 A"

    比較兩種做法時使用分頁。

=== "分頁 B"

    內容需要縮排 4 格。
```

卡片網格（用於首頁、分類首頁、章節導覽）：

```markdown
<div class="grid cards" markdown>

-   __[標題](link.md)__

    ---

    說明文字

</div>
```

### 繪圖：使用 Mermaid

**不要用框線字元（┌─┐│└┘）手繪圖**。中英文字寬不同，在網頁上會對不齊。請改用 Mermaid，深色 / 淺色模式會自動換色：

````markdown
``` mermaid
flowchart LR
    A["Master"] -- I/O Thread --> B["Slave"]
```
````

| 想畫的內容 | Mermaid 圖表 | 站內範例 |
|-----------|-------------|---------|
| 架構圖、流程圖 | `flowchart`（用 `subgraph` 分組） | `data/mysql/replication.md` |
| 兩方來回傳訊息 | `sequenceDiagram` | `network-security/network/tcp.md` |
| 狀態轉換 | `stateDiagram-v2` | `java/concurrency/thread-lifecycle.md` |
| 記憶體、分層結構、時間軸 | `block-beta`（用 `columns` 控制格線） | `java/jvm/memory-areas.md`、`java/jvm/gc.md` |
| 樹狀結構 | `block-beta` 加箭頭 | `data/mysql/index-principles.md` 的 B+樹 |

撰寫 Mermaid 時要注意：

- 節點文字含括號、斜線等符號時，用雙引號包起來：`A["Spring Boot (3.x)"]`。
- 換行用 `<br>`。
- **控制寬度**：內容區約 690px，圖比這寬就會整張縮小、文字變小。橫向（`LR`）一排最多放 4 \~ 5 個節點，太多就改成直向（`TB`），或拆成多個 `subgraph` 分列。
- **群組方向**：`subgraph` 裡的 `direction LR` 只有在節點之間有連線時才會生效。沒有連線的節點要用隱形連線 `A ~~~ B ~~~ C` 才會橫排。
- **配色**：不要自訂一般節點的背景色。需要強調時，用 `classDef` 只改外框（`stroke-width`、`stroke-dasharray`）或用透明背景；`block-beta` 的外層區塊請加 `style 區塊名稱 fill:transparent`，否則深色模式下會變成低對比的底色。
- **不要使用**：`mindmap`（節點會重疊、部分文字在這個主題下看不清楚，學習地圖請改用上述的樹狀圖）、`gantt`（文字太小，任務名稱含冒號會整張無法繪製）、`packet-beta`（64 位會被切成兩列）。
- Mermaid 放在 `???` 折疊區塊內可能無法正確繪製，請放在一般內文中。
- `block-beta` 的根層不要只放一個橫跨整列的方塊，高度會異常；把它包進子區塊（`block:xxx:3 … end`）。
- 7 個以上參與者的 `sequenceDiagram` 會太寬，改成分階段的 `flowchart` 加說明表格。
- 純表格資料（例如兩種技術的比較、判斷規則）用 Markdown 表格，不要畫成圖。
- 新增或修改圖之後，請在本機用 `python -m zensical serve` 實際看過淺色與深色兩種模式。

## 搜尋

網站使用 zensical 內建搜尋，已針對中文調整：

- `theme.language = "zh-TW"`：啟用瀏覽器內建的 `Intl.Segmenter` 進行中文斷詞。
- `[project.plugins.search]` 的 `separator`：把全形標點（，。、：「」（）等）與箭頭、框線符號也當作分詞邊界。

調整這兩項設定時，請確認中文詞（例如「索引」、「線程池」）出現在句子中間時仍搜尋得到。

## 建置與部署

本機確認能否正常建置：

```bash
python -m zensical build
```

輸出位於 `site/`（已列在 `.gitignore`）。

| 方式 | 說明 |
|------|------|
| **GitHub Pages** | push 到 `master` 時，`.github/workflows/CI.yml` 會自動建置並部署 |
| **Docker** | `Dockerfile` 會先執行 `zensical build`，再把 `site/` 放進 nginx 映像 |
