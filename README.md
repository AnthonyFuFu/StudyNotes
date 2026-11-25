# Study Notes

Study Notes 是以 zensical 建立的文件網站。文件以 Markdown 撰寫。

## 快速開始

### 需要先安裝

開始前請確認電腦已安裝：

- Python 3.11 或更新版本
- Git
- 公司 GitLab 專案的存取權限

### 1. 複製專案

開啟終端機，執行：

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

## 編輯文件

網站內容以 Markdown 撰寫。請在 `docs/` 資料夾中新增或修改 `.md` 檔案。

新增頁面後，若要讓頁面出現在網站導覽列，請在 `zensical.toml` 的 `nav` 區塊加入該檔案的路徑。路徑以 `docs/` 資料夾為起點，例如：

```yaml
nav = [
  { "Wisr" = "index.md" },
  { "Windchill" = "markdown.md" },
]
```

## 建置文件網站

要檢查文件能否正常建置，請執行看看：

```bash
python -m zensical build
```
