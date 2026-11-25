# Argo CD 與 GitOps

!!! abstract "本章重點"

    GitOps 以 Git 作為部署的唯一真實來源，由叢集內的 Argo CD 持續比對並同步。本章說明 Push 與 Pull 模式的差異、Argo CD 架構與 Application 設定，以及 Git → Harbor → Argo CD 的完整流水線。

## GitOps 是什麼

**GitOps**：以 **Git 作為部署的唯一真實來源（Single Source of Truth）**。K8s 上應該跑什麼，全部寫在 Git 裡；由叢集內的代理程式持續比對，自動把叢集調整成 Git 描述的樣子。

=== "Push 模式（傳統 CI/CD）"

    ``` mermaid
    flowchart LR
        CI["Jenkins / GitHub Actions"] -- "kubectl apply / helm upgrade" --> K8S["Kubernetes"]
    ```

    - CI 需要握有叢集的管理權限（kubeconfig），外洩風險高
    - 有人手動 `kubectl edit` 改了設定，Git 不會知道
    - 叢集實際狀態與 Git 可能早已不一致

=== "Pull 模式（GitOps / Argo CD）"

    ``` mermaid
    flowchart LR
        GIT[("Git 設定倉庫")] -- "Argo CD 持續拉取比對" --> ARGO["Argo CD（叢集內）"] -- "套用" --> K8S["Kubernetes"]
    ```

    - CI 只需要 commit 到 Git，**不需要叢集權限**
    - 手動修改會被偵測為「漂移（Drift）」，可自動修正回 Git 的狀態
    - 回滾 = `git revert`，所有變更都有 Review 紀錄

**GitOps 四原則**：宣告式、版本控制且不可變、自動拉取、持續調和（Reconcile）。

## Argo CD 架構

``` mermaid
flowchart LR
    GIT[("Git<br>Helm / Kustomize / YAML")] --> REPO["Repo Server<br>產生最終 Manifest"]
    REPO --> CTRL["Application Controller<br>比對期望狀態與實際狀態"]
    CTRL --> K8S["Kubernetes API"]
    UI["Web UI / CLI"] --> API["API Server<br>SSO、RBAC"] --> CTRL
```

| 元件 | 職責 |
|------|------|
| **API Server** | 提供 UI / CLI / API，處理 SSO 登入與 RBAC |
| **Repo Server** | 從 Git 取出內容，執行 Helm template / Kustomize build 產生 Manifest |
| **Application Controller** | 持續比較 Git 期望狀態與叢集實際狀態，顯示 Synced / OutOfSync、Healthy / Degraded，並執行同步 |

## Application

``` yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: order-service-prod
  namespace: argocd
spec:
  project: order
  source:
    repoURL: https://git.company.com/deploy/order-service.git
    targetRevision: main
    path: helm
    helm:
      valueFiles: [values-prod.yaml]
  destination:
    server: https://kubernetes.default.svc
    namespace: order
  syncPolicy:
    automated:
      prune: true        # Git 中刪除的資源，叢集也刪除
      selfHeal: true     # 有人手動改了，自動改回 Git 的狀態
    syncOptions:
      - CreateNamespace=true
```

| 狀態 | 意義 |
|------|------|
| **Synced / OutOfSync** | 叢集是否與 Git 一致 |
| **Healthy / Progressing / Degraded** | 資源本身是否正常（例如 Deployment 的 Pod 都 Ready 了沒） |

**同步的進階控制**

| 功能 | 用途 |
|------|------|
| **Sync Waves**（`argocd.argoproj.io/sync-wave`） | 控制順序：先建 ConfigMap / Secret，再部署應用 |
| **Sync Hooks**（PreSync / PostSync） | 部署前跑資料庫 Migration Job、部署後跑冒煙測試 |
| **App of Apps** | 一個 Application 管理一群 Application，一次建立整套環境 |
| **ApplicationSet** | 用產生器批次建立：每個叢集、每個環境、每個 Git 目錄各一個 Application |
| **AppProject** | 限制某團隊只能部署到哪些 namespace、從哪些 repo |

## 完整流水線：Git → Harbor → Argo CD

``` mermaid
flowchart TB
    subgraph CI ["CI 階段（Jenkins / GitLab CI）"]
        direction LR
        c1["① 合併 MR"] --> c2["② 測試<br>SonarQube"] --> c3["③ 建置映像"] --> c4[("④ 推送 Harbor<br>Trivy 掃描")]
    end
    subgraph CD ["CD 階段（Argo CD）"]
        direction LR
        d1["⑤ 更新設定倉庫<br>image.tag"] --> d2["⑥ Argo CD<br>偵測變更"] --> d3["⑦ 同步到 K8s<br>滾動更新"] --> d4(["⑧ 通知結果"])
    end
    CI --> CD
```

| 步驟 | 負責 | 產出 |
|------|------|------|
| ① \~ ③ | CI | 通過測試與靜態分析的映像，tag 為 Git commit SHA |
| ④ | Harbor | 映像存入私有倉庫並完成漏洞掃描 |
| ⑤ | CI（或 Argo CD Image Updater） | 設定倉庫中 `values-prod.yaml` 的 `image.tag` 更新為新版 |
| ⑥ \~ ⑦ | Argo CD | 比對 Git 與叢集差異，從 Harbor 拉取映像並同步 |
| ⑧ | Argo CD Notifications | Slack / Teams 通知部署結果 |

!!! tip "為什麼要分「程式碼倉庫」和「設定倉庫」"

    - 權限分離：開發者能改程式，只有維運 / 發版流程能改正式環境設定
    - 設定倉庫的 Git 歷史就是**完整的部署紀錄**：哪一版、何時、誰核准
    - 更新 tag 的步驟可以由 CI 自動 commit，或交給 **Argo CD Image Updater** 監看 Harbor 的新 tag

## 回滾與漂移

| 情境 | 做法 |
|------|------|
| 新版有問題 | 在設定倉庫 `git revert`，Argo CD 自動同步回上一版（或在 UI 一鍵 Rollback 到歷史版本） |
| 有人手動改了 Replicas | `selfHeal: true` 自動改回；若是 HPA 管理的欄位，用 `ignoreDifferences` 忽略 |
| 緊急修補 | 仍然走 Git：直接改設定倉庫，保留紀錄 |

## Argo 家族

| 專案 | 用途 |
|------|------|
| **Argo CD** | GitOps 持續部署 |
| **Argo Rollouts** | 進階部署策略：**金絲雀**、**藍綠**，可依 Prometheus 指標自動判斷要繼續放量或回滾 |
| **Argo Workflows** | K8s 上的 DAG 工作流程引擎（批次、資料處理、ML Pipeline） |
| **Argo Events** | 事件驅動：Webhook、訊息佇列事件觸發 Workflow |

``` yaml
# Argo Rollouts 金絲雀：先 20% 流量，觀察指標通過後再逐步放大
strategy:
  canary:
    steps:
      - setWeight: 20
      - pause: { duration: 5m }
      - analysis: { templates: [ { templateName: error-rate-below-1pct } ] }
      - setWeight: 50
      - pause: { duration: 5m }
```

## 優點與缺點

=== "優點"

    - **可稽核**：每一次部署都是一個 Git commit，誰、何時、改了什麼一清二楚
    - **安全**：CI 不需要叢集權限，叢集也不需要對外開放 API
    - **防漂移**：手動修改會被偵測並自動修正
    - **多叢集**：一套 Argo CD 管理開發、測試、正式多個叢集
    - UI 直接看到每個資源的狀態樹與差異

=== "缺點"

    - 多了「設定倉庫」與「更新 tag」的流程，小團隊會覺得繁瑣
    - Secret 不能明文放 Git，要搭配 Sealed Secrets、SOPS 或 External Secrets
    - 依賴順序（資料庫 Migration、CRD）要用 Sync Wave / Hook 仔細設計
    - Argo CD 本身也需要高可用與權限管理
