# Docker 深入

## Docker 核心原理

**Docker 不是虛擬機！**

=== "虛擬機（VM）"

    ``` mermaid
    block-beta
        columns 2
        A["App A"] B["App B"]
        GA["Guest OS"] GB["Guest OS"]
        H["Hypervisor"]:2
        OS["Host OS"]:2
        HW["Hardware"]:2
    ```

=== "Docker 容器"

    ``` mermaid
    block-beta
        columns 2
        A["App A"] B["App B"]
        R["Container Runtime"]:2
        OS["Host OS"]:2
        HW["Hardware"]:2
    ```

| | 虛擬機 VM | 容器 Container |
|---|---|---|
| 作業系統 | 每個都有完整 Guest OS | 共享 Host OS 核心 |
| 啟動速度 | 慢（分鐘） | 快（秒） |
| 資源佔用 | GB 級 | MB 級 |

Docker 底層由三項 Linux 技術組成：

**① Namespace（命名空間）：隔離**

| Namespace | 隔離內容 |
|-----------|---------|
| PID | 容器有自己的進程 ID 空間 |
| Network | 獨立的網路介面、IP |
| Mount | 獨立的文件系統視圖 |
| UTS | 獨立的主機名 |
| IPC | 獨立的進程間通訊 |
| User | 獨立的用戶 / 組 ID |

**② Cgroups（Control Groups）：限制資源**

| 資源 | 參數 |
|------|------|
| CPU 使用率 | `--cpus="0.5"`（最多用半個核） |
| 記憶體 | `--memory="512m"` |
| 磁碟 IO | `--device-write-bps` |

**③ Union File System（UnionFS）：分層儲存**

Image 是只讀的分層結構，容器運行時在最上面加一個可寫層（Container Layer）。

``` mermaid
block-beta
    columns 1
    CL["Container Layer（可寫，容器刪除即消失）"]
    block:IMG
        columns 1
        APP["App Layer（你的應用）"]
        DEP["Dependencies Layer（依賴）"]
        JDK["JDK Layer"]
        BASE["Base OS Layer（ubuntu / alpine）"]
    end
```

下方四層為 **Image（只讀分層）**。多個容器可以共享相同的底層，節省空間，例如 ubuntu 層只需要下載一次。

## Dockerfile 最佳實踐

```dockerfile
# ❌ 糟糕的 Dockerfile（初學者常犯）
FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y openjdk-17-jdk
RUN apt-get install -y maven
COPY . /app
WORKDIR /app
RUN mvn clean package
EXPOSE 8080
CMD ["java", "-jar", "target/app.jar"]

# 問題：
# 1. ubuntu 太大（72MB），應用不需要 apt-get
# 2. 每個 RUN 都是一層，層數太多
# 3. COPY . 複製了所有文件包括源碼（Image 很大）
# 4. Maven 也打進去了（不需要）
# 5. 沒有利用 Docker 緩存（每次都全量重建）
```

```dockerfile
# ✅ 多階段建置（Multi-Stage Build）最佳實踐

# ──────────── 階段一：建置階段 ────────────
FROM maven:3.9.5-eclipse-temurin-17-alpine AS builder

WORKDIR /build

# ⭐ 技巧：先複製 pom.xml，下載依賴（利用 Docker 緩存！）
# 只要 pom.xml 不變，這一層永遠使用緩存，不重複下載依賴
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 再複製源碼（源碼經常變動，放後面）
COPY src ./src

# 建置（跳過測試，測試在 CI 中已執行）
RUN mvn clean package -DskipTests -B

# ──────────── 階段二：運行階段 ────────────
FROM eclipse-temurin:17-jre-alpine AS runtime
# 只用 JRE（不需要 JDK），alpine 版本（~60MB vs ubuntu ~400MB）

# 安全：不用 root 運行
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# 只從建置階段複製 jar（不含源碼、Maven、JDK！）
COPY --from=builder /build/target/app-*.jar app.jar

# ⭐ JVM 參數最佳化（容器友好）
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -Djava.security.egd=file:/dev/./urandom"
# UseContainerSupport：讓 JVM 感知容器的 CPU/記憶體限制
# MaxRAMPercentage：最多用容器記憶體的 75%
# java.security.egd：加速隨機數生成（解決容器啟動慢問題）

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

# 切換非 root 用戶
USER appuser

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

```bash
# 建置與查看分層
docker build -t myapp:1.0.0 .

# 查看 Image 大小
docker images myapp

# 查看 Image 分層
docker history myapp:1.0.0

# 標準 Image 命名規範
# registry/namespace/repository:tag
docker build -t harbor.example.com/backend/order-service:v1.2.3 .

# 推送到 Registry
docker push harbor.example.com/backend/order-service:v1.2.3
```

## Docker Compose（本地開發環境）

```yaml
# docker-compose.yml（完整的本地開發環境）
version: '3.8'

services:

  # ── 應用服務 ──
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime
    image: myapp:dev
    container_name: myapp
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/mydb
      SPRING_DATASOURCE_USERNAME: root
      SPRING_DATASOURCE_PASSWORD: password
      SPRING_REDIS_HOST: redis
      SPRING_RABBITMQ_HOST: rabbitmq
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./logs:/app/logs
    networks:
      - backend
    restart: unless-stopped

  # ── MySQL ──
  mysql:
    image: mysql:8.0
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: mydb
      MYSQL_CHARACTER_SET_SERVER: utf8mb4
      MYSQL_COLLATION_SERVER: utf8mb4_unicode_ci
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  # ── Redis ──
  redis:
    image: redis:7.2-alpine
    container_name: redis
    command: redis-server --requirepass password --maxmemory 512mb --maxmemory-policy allkeys-lru
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "password", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    networks:
      - backend

  # ── RabbitMQ ──
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: password
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - backend

  # ── Nginx 反向代理 ──
  nginx:
    image: nginx:1.25-alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    networks:
      - backend

volumes:
  mysql_data:
  redis_data:
  rabbitmq_data:

networks:
  backend:
    driver: bridge
```

```bash
# Docker Compose 常用指令

docker-compose up -d              # 啟動所有服務（背景執行）
docker-compose up -d --build      # 啟動並重新建置
docker-compose ps                 # 查看服務狀態
docker-compose logs -f app        # 查看日誌（持續追蹤）
docker-compose restart app        # 只重啟 app 服務
docker-compose down               # 停止並刪除容器（保留數據卷）
docker-compose down -v            # 停止並刪除容器+數據卷（慎用！）
docker-compose exec app sh        # 進入容器 shell
docker-compose up -d --scale app=3 # 擴展服務實例數量
```

## Docker 網路

| 網路模式 | 說明 | 用法 |
|---------|------|------|
| **① Bridge**（預設） | 容器有自己的 IP，通過虛擬網橋通訊；容器間可以用 container_name 互相訪問 | 預設 |
| **② Host** | 容器直接使用主機網路，效能最好，但沒有網路隔離 | `--network host` |
| **③ None** | 無網路（完全隔離） | `--network none` |
| **④ Overlay** | 跨主機的容器通訊（Swarm / K8s 使用） | |

**Bridge 模式示意**

``` mermaid
flowchart LR
    H["Host"] --- D["docker0<br>172.17.0.1"]
    D --- C1["container1<br>172.17.0.2"]
    D --- C2["container2<br>172.17.0.3"]
```

```bash
# 自定義 Bridge 網路（推薦）
docker network create my-network

# 容器加入網路後，可以用 container name 直接互相訪問
docker run --network my-network --name app myapp
docker run --network my-network --name mysql mysql:8.0
# app 容器中可以直接用 mysql:3306 訪問 MySQL ✅
```
