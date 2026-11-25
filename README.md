# Study Notes

Java 後端工程師的深度學習筆記網站，以 [zensical](https://zensical.org/) 建立，內容以 Markdown 撰寫。

筆記系統性整理 Java 後端核心知識體系，共 **6 大分類、17 個主題、100+ 個章節**：

| 分類 | 主題 |
|------|------|
| Java 核心 | Java 新特性 / JVM 深度原理 / Java 並發 |
| 資料儲存 | MySQL 深度優化 / Redis 深度 / Elasticsearch |
| 架構設計 | 系統設計 / 設計模式 / Spring Cloud 微服務 / API 設計與通訊協議 |
| 網路與資安 | 網路基礎 / 資安 |
| 工程實踐 | 測試 / CI/CD 與 DevOps / 監控與可觀測性 |
| 演算法與前端 | 演算法與資料結構 / 前端深度 |

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
    ├── markdown.md          # 附錄：Markdown 語法速查
    ├── assets/images/       # 圖片
    └── <分類>/              # java、data、architecture、network-security、engineering、fundamentals
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

`zensical.toml` 已開啟 `navigation.tabs`（分類顯示在上方分頁）、`navigation.indexes`（資料夾的 `index.md` 作為該區段首頁）與 `toc.follow`（右側目錄跟隨捲動）。

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

3. 主題首頁依序放：簡介與核心技術 → `## 學習地圖`（mindmap）→ `## 章節導覽`（卡片）→ `## 重點速覽` → `## 核心要點總結`。
4. 在 `zensical.toml` 的 `nav` 加入主題區塊，並在分類首頁加上主題卡片。

## 書寫規則

- **標題**：每頁只有一個 `#`；章節內用 `##`、`###`，它們會出現在右側目錄。標題不加裝飾用的 emoji。
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
| 記憶體、分層結構 | `block-beta` | `java/jvm/memory-areas.md` |
| 時間軸、耗時 | `gantt` | `engineering/monitoring/tracing.md` |
| 位元欄位 | `packet-beta` | `data/mysql/sharding.md` |
| 學習路線、分類樹 | `mindmap` | 各主題首頁的「學習地圖」 |

撰寫 Mermaid 時要注意：

- 節點文字含括號、斜線等符號時，用雙引號包起來：`A["Spring Boot (3.x)"]`。
- 換行用 `<br>`。
- 不要自訂背景色，否則深色模式下會看不清楚。
- Mermaid 放在 `???` 折疊區塊內可能無法正確繪製，請放在一般內文中。
- 純表格資料（例如兩種技術的比較）用 Markdown 表格，不要畫成圖。

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
