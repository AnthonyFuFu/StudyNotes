# Git 協作流程

!!! abstract "本章重點"

    CI/CD 的起點是 Git。分支策略決定了什麼時候觸發建置、什麼版本可以上線。本章比較 Git Flow、GitHub Flow 與 Trunk-Based Development，說明 Merge 與 Rebase 的差異、Conventional Commits 與語意化版本，以及 Code Review 的實務。

## 三種分支策略

=== "Git Flow"

    ``` mermaid
    flowchart LR
        F["feature/*"] --> D["develop"] --> R["release/*"] --> M["main（tag v1.2.0）"]
        H["hotfix/*"] --> M
        H --> D
    ```

    - `main` 只放已發布的版本，`develop` 是整合分支
    - **適合**：有固定發版週期、同時維護多個版本的產品
    - **缺點**：分支多、合併衝突多，與持續部署不太搭

=== "GitHub Flow"

    ``` mermaid
    flowchart LR
        M["main（隨時可部署）"] --> F["feature/xxx"] --> PR["Pull Request<br>CI + Review"] --> M
    ```

    - 只有 `main` 與短命的功能分支，合併後就部署
    - **適合**：Web 服務、持續部署的團隊

=== "Trunk-Based"

    ``` mermaid
    flowchart LR
        T["main（trunk）"] --> S["短命分支<br>1 ～ 2 天"] --> T
        T --> FF["Feature Flag<br>未完成功能先關閉"]
    ```

    - 所有人頻繁合併回主幹，未完成的功能用 **Feature Flag** 隱藏
    - **適合**：高頻部署、測試自動化完整的團隊

| | Git Flow | GitHub Flow | Trunk-Based |
|---|----------|-------------|-------------|
| 長期分支 | main + develop | main | main |
| 發版方式 | release 分支 + tag | 合併即部署 | 持續部署 + Feature Flag |
| 合併衝突 | 多 | 少 | 最少 |
| 對 CI 的要求 | 中 | 高 | 非常高 |

!!! example "我的專案"

    holidayDessert 的 CI 監聽 `master`、`pre-production`、`production` 三個分支，屬於「環境分支」的做法：程式碼依序合併到預發布與正式分支，各自觸發對應環境的建置。

## Merge 與 Rebase

=== "Merge"

    ``` bash
    git switch main
    git merge feature/payment        # 產生一個合併 commit，保留分支歷史
    ```

    - ✅ 保留真實歷史，不改寫任何 commit
    - ❌ 歷史線圖會有很多分岔

=== "Rebase"

    ``` bash
    git switch feature/payment
    git rebase main                  # 把自己的 commit 接到 main 最新的後面
    ```

    - ✅ 歷史是一條直線，好讀
    - ❌ 會改寫 commit，**已推送、別人也在用的分支不要 rebase**

=== "Squash Merge"

    PR 合併時把所有 commit 壓成一個。功能分支上「修 typo」「再修一次」這類 commit 不會進到主幹。

!!! tip "常見的團隊約定"

    - 自己的功能分支：`git pull --rebase` 跟上 main，保持整齊
    - 合併到 main：用 PR 的 **Squash Merge** 或 **Merge Commit**，不要直接 push
    - 已共享的分支：只用 merge，不用 rebase、不 `push --force`（真的需要時用 `--force-with-lease`）

## Conventional Commits 與語意化版本

``` text
feat(ticket): 新增電腦自動配位
fix(order): 修正付款逾時未釋放庫存
refactor(cache): 抽出 Redis Key 產生邏輯
docs: 更新部署說明
chore(deps): 升級 Spring Boot 3.5.16
```

| 類型 | 用途 | 影響版本 |
|------|------|---------|
| `feat` | 新功能 | MINOR（1.**2**.0） |
| `fix` | 修正錯誤 | PATCH（1.2.**1**） |
| `feat!` / `BREAKING CHANGE` | 不相容的變更 | MAJOR（**2**.0.0） |
| `refactor` / `perf` / `docs` / `test` / `chore` | 其他 | 不影響 |

有了一致的格式，就能**自動產生 CHANGELOG 與版本號**（semantic-release、release-please）。我的 commit 訊息使用 `feat:`、`fix:` 前綴，就是這個規範的簡化版。

## Code Review 與保護分支

| 設定 | 作用 |
|------|------|
| **Branch Protection** | `main` 禁止直接 push，必須透過 PR |
| **Required Status Checks** | CI（建置、測試、SonarQube）通過才能合併 |
| **Required Reviews** | 至少一位審核者核准 |
| **CODEOWNERS** | 修改特定目錄時，自動指派負責人審核 |

**Review 時看什麼**：正確性與邊界條件 → 交易與並發 → 安全（輸入驗證、權限、敏感資訊） → 測試是否涵蓋 → 命名與可讀性。格式問題交給 Prettier、Checkstyle 等工具，不要在 Review 中爭論。

## 常用但容易忘記的指令

| 情境 | 指令 |
|------|------|
| 修改最後一次 commit | `git commit --amend` |
| 暫存目前修改 | `git stash` / `git stash pop` |
| 把某個 commit 套到目前分支 | `git cherry-pick <sha>` |
| 安全地撤銷已推送的 commit | `git revert <sha>` |
| 找出是哪個 commit 引入 bug | `git bisect start` → `bad` / `good` |
| 找回不小心刪掉的 commit | `git reflog` |
| 誰改了這一行 | `git blame -L 10,20 file` |
