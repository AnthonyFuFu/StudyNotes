# Kubernetes 深入

## K8s 整體架構

``` mermaid
flowchart TB
    subgraph CP ["Control Plane（主節點）"]
        direction LR
        API["API Server<br>集群入口，所有操作都經過它"]
        ETCD[("etcd<br>分散式 KV 存儲<br>集群狀態")]
        CM["Controller Manager<br>Node / Deployment /<br>ReplicaSet / Service Ctrl"]
        SCH["Scheduler<br>決定 Pod 運行在哪個 Node"]
        API <--> ETCD
        CM <--> API
        SCH <--> API
    end
    subgraph N1 ["Worker Node 1"]
        direction TB
        K1["kubelet / kube-proxy"] --> P11["Pod"] & P12["Pod"]
    end
    subgraph N2 ["Worker Node 2"]
        direction TB
        K2["kubelet / kube-proxy"] --> P21["Pod"] & P22["Pod"]
    end
    subgraph N3 ["Worker Node 3"]
        direction TB
        K3["kubelet / kube-proxy"] --> P31["Pod"]
    end
    API -- 控制 --> K1 & K2 & K3
```

**核心組件職責**

| 組件 | 職責 |
|------|------|
| **API Server** | 集群的統一入口，所有操作都通過 RESTful API |
| **etcd** | 儲存所有集群狀態（高可用 KV 存儲） |
| **Scheduler** | 根據資源需求選擇最合適的 Node |
| **Controller** | 持續監控集群狀態，確保實際狀態 = 期望狀態 |
| **kubelet** | 每個 Node 上的代理，負責 Pod 的生命週期 |
| **kube-proxy** | 每個 Node 上的網路代理，實現 Service 負載均衡 |

## 核心資源對象

### Pod（最小部署單元）

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp-pod
  namespace: production
  labels:
    app: myapp
    version: v1.0.0
spec:
  containers:
    - name: myapp
      image: harbor.example.com/backend/myapp:v1.0.0

      resources:
        requests:
          cpu: "250m"
          memory: "512Mi"
        limits:
          cpu: "500m"
          memory: "1Gi"

      ports:
        - containerPort: 8080

      env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: db-password

      # 存活探針（失敗則重啟容器）
      livenessProbe:
        httpGet:
          path: /actuator/health/liveness
          port: 8080
        initialDelaySeconds: 60
        periodSeconds: 15
        failureThreshold: 3

      # 就緒探針（失敗則從 Service 摘除）
      readinessProbe:
        httpGet:
          path: /actuator/health/readiness
          port: 8080
        initialDelaySeconds: 30
        periodSeconds: 10
        failureThreshold: 3

      # 啟動探針（慢啟動應用用這個）
      startupProbe:
        httpGet:
          path: /actuator/health
          port: 8080
        failureThreshold: 30
        periodSeconds: 10
```

### Deployment（管理無狀態應用）

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  namespace: production
spec:
  replicas: 3

  selector:
    matchLabels:
      app: myapp

  # 滾動更新策略
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 更新時最多多出 1 個 Pod
      maxUnavailable: 0  # 更新時最多不可用 0 個（始終保持 3 個可用）
      # 這個配置保證 0 停機更新！

  template:
    metadata:
      labels:
        app: myapp
        version: v1.0.0
    spec:
      # Pod 反親和性（讓 Pod 分散到不同 Node）
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - myapp
                topologyKey: kubernetes.io/hostname

      terminationGracePeriodSeconds: 60

      containers:
        - name: myapp
          image: harbor.example.com/backend/myapp:v1.0.0
          imagePullPolicy: Always

          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"

          ports:
            - containerPort: 8080

          envFrom:
            - configMapRef:
                name: myapp-config
            - secretRef:
                name: myapp-secrets

          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 15

          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10

          volumeMounts:
            - name: config-volume
              mountPath: /app/config
              readOnly: true
            - name: log-volume
              mountPath: /app/logs

      volumes:
        - name: config-volume
          configMap:
            name: myapp-config-files
        - name: log-volume
          emptyDir: {}

      imagePullSecrets:
        - name: harbor-credentials
```

### Service（服務發現與負載均衡）

```yaml
# ── ClusterIP（集群內部訪問，預設）──
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
    - name: http
      port: 80
      targetPort: 8080

---
# ── NodePort（暴露到節點端口，適合測試）──
apiVersion: v1
kind: Service
metadata:
  name: myapp-nodeport
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080   # 訪問方式：http://<Node_IP>:30080

---
# ── LoadBalancer（雲平台負載均衡器，適合生產）──
apiVersion: v1
kind: Service
metadata:
  name: myapp-lb
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

### Ingress（HTTP 路由層）

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/limit-rps: "100"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx

  tls:
    - hosts:
        - api.example.com
      secretName: myapp-tls-secret

  rules:
    - host: api.example.com
      http:
        paths:
          - path: /api/orders
            pathType: Prefix
            backend:
              service:
                name: order-service
                port:
                  number: 80

          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: user-service
                port:
                  number: 80

          - path: /api/products
            pathType: Prefix
            backend:
              service:
                name: product-service
                port:
                  number: 80
```

### ConfigMap 與 Secret

```yaml
# configmap.yaml（非敏感配置）
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  SPRING_PROFILES_ACTIVE: "production"
  SERVER_PORT: "8080"
  LOG_LEVEL: "INFO"

  application.yml: |
    spring:
      datasource:
        url: jdbc:mysql://mysql-service:3306/mydb
        driver-class-name: com.mysql.cj.jdbc.Driver
      redis:
        host: redis-service
        port: 6379
    server:
      port: 8080

---
# secret.yaml（敏感配置，Base64 編碼）
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: production
type: Opaque
data:
  # echo -n "mypassword" | base64
  db-password:    bXlwYXNzd29yZA==
  redis-password: cmVkaXNwYXNz
  jwt-secret:     c3VwZXItc2VjcmV0LWtleQ==

# ⚠️ Secret 只是 Base64 編碼，不是加密！
# 生產環境建議：
# ① Vault（HashiCorp）- 企業級密鑰管理
# ② Sealed Secrets（Bitnami）- 加密儲存在 Git
# ③ 雲平台 KMS（AWS Secrets Manager / GCP Secret Manager）
```

```bash
# 從命令行建立 Secret（不用手動 base64）
kubectl create secret generic myapp-secrets \
  --from-literal=db-password=mypassword \
  --from-literal=redis-password=redispass \
  -n production

# 從文件建立 Secret
kubectl create secret generic tls-secret \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem \
  -n production
```

### HPA（Horizontal Pod Autoscaler）自動擴縮容

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp-deployment

  minReplicas: 2
  maxReplicas: 20

  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70

    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - type: Pods
          value: 4
          periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300   # 5分鐘，防止抖動
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
```

## 滾動更新與回滾

```bash
# ── 滾動更新 ──

# 方式一：更新 Image（最常用）
kubectl set image deployment/myapp-deployment \
  myapp=harbor.example.com/backend/myapp:v1.1.0 \
  -n production

# 查看更新進度
kubectl rollout status deployment/myapp-deployment -n production

# 查看更新歷史
kubectl rollout history deployment/myapp-deployment -n production
# REVISION  CHANGE-CAUSE
# 1         初始部署
# 2         更新到 v1.1.0

# ── 回滾 ──

# 回滾到上一個版本
kubectl rollout undo deployment/myapp-deployment -n production

# 回滾到指定版本
kubectl rollout undo deployment/myapp-deployment \
  --to-revision=2 -n production

# 記錄變更原因
kubectl annotate deployment/myapp-deployment \
  kubernetes.io/change-cause="修復登入 Bug，更新到 v1.1.0" \
  -n production
```

```
滾動更新流程（maxSurge=1, maxUnavailable=0, replicas=3）：

初始狀態：  [v1] [v1] [v1]
步驟 1：    [v1] [v1] [v1] [v2]     ← 新增 v2（surge）
步驟 2：    [v1] [v1]      [v2]     ← 移除一個 v1
步驟 3：    [v1] [v1] [v2] [v2]     ← 新增 v2
步驟 4：    [v1]      [v2] [v2]     ← 移除一個 v1
步驟 5：    [v1] [v2] [v2] [v2]     ← 新增 v2
步驟 6：         [v2] [v2] [v2]     ← 移除最後一個 v1

✅ 全程保持 3 個可用 Pod（0 停機！）
```

## StatefulSet（有狀態應用）

```yaml
# statefulset.yaml（適合 MySQL、Kafka、Elasticsearch 等）
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: production
spec:
  serviceName: mysql-headless
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: root-password
          ports:
            - containerPort: 3306
          volumeMounts:
            - name: mysql-data
              mountPath: /var/lib/mysql

  # 每個 Pod 都有自己的 PVC！
  volumeClaimTemplates:
    - metadata:
        name: mysql-data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: ssd-storage
        resources:
          requests:
            storage: 100Gi

# StatefulSet 的 Pod 有穩定的網路標識：
#   mysql-0、mysql-1、mysql-2
# 刪除重建後，名字和 PVC 不變！
# 適合：主從 MySQL、Kafka、ZooKeeper、Redis Cluster
```
