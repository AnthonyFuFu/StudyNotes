# 運算與部署：EC2、ECS、EKS、Lambda

!!! abstract "本章重點"

    AWS 的運算服務從 EC2、ECS、EKS 到 Lambda，管得越少、彈性越低。本章比較各服務的適用情境，說明負載平衡與自動擴展、ECS 與 EKS 的差異，以及常見的部署策略。

## 運算服務怎麼選

``` mermaid
flowchart LR
    EC2["EC2<br>自己管 OS"] --> ECS["ECS<br>AWS 原生容器編排"] --> EKS["EKS<br>託管 Kubernetes"] --> LAMBDA["Lambda<br>無伺服器"]
```

由左到右：**管得越少、彈性越低、計費越細**。

| 服務 | 你要管 | 適合 | 計費 |
|------|-------|------|------|
| **EC2** | OS、修補、執行環境、擴縮容 | 需要完全掌控、舊系統搬遷 | 依執行個體時數 |
| **ECS on EC2** | EC2 節點 + 容器 | 想用容器又不想學 K8s | 依 EC2 |
| **ECS on Fargate** | 只管容器 | 中小型容器服務，零節點維運 | 依 vCPU / 記憶體秒數 |
| **EKS** | K8s 工作負載（控制平面由 AWS 管） | 已有 K8s 生態：Helm、**Argo CD**、多雲 | 叢集費 + 節點費 |
| **Lambda** | 只管函式 | 事件驅動、流量不穩定、排程任務 | 依請求數與執行時間 |

## EC2

| 主題 | 重點 |
|------|------|
| 執行個體類型 | `t` 系列可突發（開發）、`m` 通用、`c` 運算優化、`r` 記憶體優化；`g` 系列為 Graviton（ARM），性價比高 |
| 購買方式 | On-Demand（彈性）、Savings Plans / Reserved（長期穩定負載省 40% 以上）、**Spot**（省到 90%，可能被回收，適合批次與 CI Runner） |
| 儲存 | **EBS**：區塊儲存，綁定 AZ；**Instance Store**：本機碟，關機即消失 |
| AMI | 機器映像檔，搭配 Packer 預先烤好環境 |

### 負載平衡與自動擴展

``` mermaid
flowchart LR
    U(["使用者"]) --> R53["Route 53"] --> ALB["ALB<br>HTTPS 終止、路徑路由"]
    ALB --> TG["Target Group<br>健康檢查"]
    TG --> ASG["Auto Scaling Group<br>跨 AZ 的 EC2"]
```

| 負載平衡器 | 層級 | 用途 |
|-----------|------|------|
| **ALB** | L7（HTTP） | 依路徑 / Host 路由、WebSocket、搭配 ACM 憑證 |
| **NLB** | L4（TCP / UDP） | 極低延遲、固定 IP、gRPC 長連線 |

**Auto Scaling 策略**：目標追蹤（維持 CPU 50%）、排程擴展（固定時段的流量高峰）、預測擴展。搶票這類**可預期的瞬間流量**，要用排程提前擴容，因為新機器開機需要時間。

## 容器：ECR、ECS、EKS

``` mermaid
flowchart LR
    CI["CI 建置映像"] --> REG[("ECR / Harbor")]
    REG --> ECS["ECS Service<br>Task Definition"]
    REG --> EKS["EKS<br>Deployment"]
```

| | ECS | EKS |
|---|-----|-----|
| 核心概念 | Task Definition（容器規格）→ Service（維持數量、滾動更新） | Pod、Deployment、Service、Ingress |
| 學習成本 | 低，AWS 主控台就能完成 | 高，需要懂 Kubernetes |
| 生態 | AWS 專屬 | Helm、Argo CD、Prometheus 等 CNCF 工具通用 |
| 可攜性 | 綁定 AWS | 可搬到其他雲或自建叢集 |
| 對外流量 | ALB 直接接 Service | **AWS Load Balancer Controller** 依 Ingress 建立 ALB |

!!! info "EKS 常用的附加元件"

    - **AWS Load Balancer Controller**：Ingress → ALB、Service → NLB
    - **EBS / EFS CSI Driver**：PersistentVolume 用 EBS 或 EFS
    - **Karpenter** / Cluster Autoscaler：依 Pod 需求自動增減節點
    - **IRSA / Pod Identity**：每個 Pod 拿到自己的 IAM Role
    - **External Secrets Operator**：把 Secrets Manager 的值同步成 K8s Secret

## Lambda：無伺服器

``` java
public class ResizeHandler implements RequestHandler<S3Event, Void> {
    @Override
    public Void handleRequest(S3Event event, Context context) {
        event.getRecords().forEach(r -> {
            String key = r.getS3().getObject().getKey();
            // 使用者上傳原圖後，自動產生縮圖
        });
        return null;
    }
}
```

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 不用管伺服器，用多少付多少 | **冷啟動**：Java 尤其明顯（可用 SnapStart 改善） |
| 自動擴展到大量並發 | 單次執行最長 15 分鐘 |
| 與 S3、SQS、EventBridge 事件整合 | 本機除錯、監控較麻煩 |

## 部署策略

| 策略 | 做法 | AWS / K8s 對應 |
|------|------|---------------|
| 滾動更新 | 分批替換舊版 | ECS Rolling Update、K8s Deployment |
| 藍綠部署 | 新舊兩套並存，一次切換流量 | CodeDeploy Blue/Green、ALB 切換 Target Group |
| 金絲雀 | 先導少量流量到新版觀察 | ALB 權重路由、**Argo Rollouts** |
