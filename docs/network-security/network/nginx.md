# Nginx 反向代理與負載均衡

!!! abstract "本章重點"

    幾乎所有網站的最前面都站著一台 Nginx：負責 HTTPS、靜態檔案、反向代理與負載均衡。本章說明 Nginx 的事件驅動架構、常用設定（反向代理、負載均衡、SPA 路由、WebSocket、快取與限流），並以 StudyNotes 本身的部署設定為例。

## 為什麼前面要放 Nginx

``` mermaid
flowchart LR
    U(["使用者"]) -- "HTTPS :443" --> N["Nginx"]
    N -- "/" --> S[("靜態檔案<br>Vue / Angular build")]
    N -- "/api" --> A1["Spring Boot #1"]
    N -- "/api" --> A2["Spring Boot #2"]
```

| 職責 | 說明 |
|------|------|
| **反向代理** | 使用者只看到 Nginx，後端服務的位址與數量對外隱藏 |
| **負載均衡** | 把請求分散到多台應用程式 |
| **TLS 終止** | HTTPS 在 Nginx 解密，後端只處理 HTTP，憑證集中管理 |
| **靜態檔案** | 直接回傳前端打包結果、圖片，比交給 Java 處理快得多 |
| **統一入口** | 前端與 API 同一個網域，**不需要處理 CORS** |
| **防護** | 限流、限制請求大小、隱藏版本號、擋惡意 User-Agent |

## 為什麼 Nginx 能撐住大量連線

``` mermaid
flowchart TB
    M["Master 程序<br>讀設定、管理 Worker"] --> W1["Worker 1"] & W2["Worker 2"] & W3["Worker N<br>（≈ CPU 核心數）"]
    W1 --> E["epoll 事件迴圈<br>一個 Worker 同時處理數萬連線"]
```

每個 Worker 都是**單執行緒 + 非阻塞 I/O（epoll）**，等待後端回應時不會卡住，可以繼續處理其他連線。這與 [Spring WebFlux 的 Event Loop](../../backend/webflux/reactive.md) 是同一個思路；相比之下，Apache 傳統的 prefork 模式是一個連線一個程序。

## 常用設定

=== "反向代理 + 負載均衡"

    ``` nginx
    upstream order_service {
        least_conn;                         # 連線數最少的優先
        server 10.0.1.11:8080 weight=2;     # 權重較高，分到較多請求
        server 10.0.1.12:8080;
        server 10.0.1.13:8080 backup;       # 其他都掛了才使用
        keepalive 32;                       # 與後端維持長連線
    }

    server {
        listen 443 ssl;
        server_name shop.example.com;

        location /api/ {
            proxy_pass http://order_service;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 3s;
            proxy_read_timeout    30s;
        }
    }
    ```

=== "HTTPS"

    ``` nginx
    server {
        listen 80;
        server_name shop.example.com;
        return 301 https://$host$request_uri;          # HTTP 一律導向 HTTPS
    }

    server {
        listen 443 ssl http2;
        server_name shop.example.com;
        ssl_certificate     /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    }
    ```

=== "SPA 前端"

    ``` nginx
    location / {
        root  /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;              # 找不到檔案時交給前端路由
    }

    location ~* \.(js|css|png|jpg|svg|woff2)$ {
        root /usr/share/nginx/html;
        expires 1y;                                     # 檔名帶 hash，可以長期快取
        add_header Cache-Control "public, immutable";
    }
    ```

=== "WebSocket"

    ``` nginx
    location /ws-chat {
        proxy_pass http://order_service;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;      # 轉送升級請求
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;                       # 長連線不要太快斷
    }
    ```

=== "限流"

    ``` nginx
    # 每個 IP 每秒 10 個請求，可以累積 20 個突發
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    location /api/tickets/purchase {
        limit_req zone=api burst=20 nodelay;
        limit_req_status 429;
        proxy_pass http://order_service;
    }
    ```

## 負載均衡策略

| 策略 | 設定 | 適合 |
|------|------|------|
| 輪詢（預設） | — | 各節點規格相同 |
| 加權輪詢 | `weight=N` | 機器規格不同 |
| 最少連線 | `least_conn` | 請求處理時間差異大 |
| IP Hash | `ip_hash` | 需要 Session 黏著（建議改用 Redis Session 或 JWT） |
| 一致性 Hash | `hash $request_uri consistent` | 快取型服務，節點增減時影響最小 |

!!! warning "後端要拿到真實的使用者 IP"

    經過 Nginx 之後，後端看到的來源 IP 都是 Nginx。要靠 `X-Forwarded-For` / `X-Real-IP` 傳遞，Spring Boot 設定 `server.forward-headers-strategy=native`（或 `framework`），`request.getRemoteAddr()` 與產生的重新導向網址才會正確。限流、稽核紀錄都依賴這個值。

## 我的實作：StudyNotes 的部署

StudyNotes 的 Dockerfile 先用 Python 映像執行 `zensical build`，再把產生的 `site/` 放進 Nginx 映像（多階段建置）。`nginx-custom.conf` 有兩個重點：

``` nginx
client_body_temp_path /tmp/client_temp;   # 暫存目錄改到 /tmp
proxy_temp_path       /tmp/proxy_temp;

server {
  listen 8000;                            # 用非 1024 以下的 port
  location / {
    root /usr/share/nginx/html;
    index index.html;
  }
  error_page 404 /index.html;
}
```

| 設定 | 原因 |
|------|------|
| 暫存目錄改到 `/tmp`、`pid` 改到 `/tmp/nginx.pid` | 容器以**非 root 使用者**（UID 1001）執行，沒有權限寫入預設路徑 |
| 監聽 `8000` 而不是 `80` | 非 root 程序不能綁定 1024 以下的 port |

以非 root 身分執行容器，是 Kubernetes 安全基準（Pod Security Standards）的要求之一。

## Nginx 與其他入口元件

| 元件 | 層級 | 適合 |
|------|------|------|
| **Nginx** | L7 反向代理、靜態檔案 | 單機或 VM 部署的通用入口 |
| **Spring Cloud Gateway** | 應用層閘道 | 需要與 Java 程式整合的路由、認證、灰度 |
| **K8s Ingress（ingress-nginx）** | 叢集入口 | 用 Ingress YAML 宣告路由，底層仍是 Nginx |
| **AWS ALB** | 託管 L7 負載平衡 | 部署在 AWS 上，免維運 |
