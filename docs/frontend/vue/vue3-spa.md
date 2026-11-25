# 實戰：Vue 3 前後端分離

!!! abstract "本章重點"

    本章以 holiday_dessert_vue 說明 Vue 3 前後端分離的實作：巢狀版型與懶加載路由、跨網域與 Cookie 的處理、STOMP 即時客服、Vuex 與 Pinia 的比較，以及打包部署。

!!! abstract "專案：holiday_dessert_vue"

    holidayDessert 前台的 Vue 3 單頁應用（SPA）版本：Vue CLI 5 + Vue Router 4 + Vuex 4 + Axios + Sass，開發伺服器跑在 `8081`，所有資料都透過 API 向 Spring Boot 後端（`8080`）取得。

## 專案結構

``` text
src/
├── main.js          # 建立 App、掛載 Router / Store、Axios 全域設定
├── App.vue
├── router/          # 路由設定（懶加載）
├── layouts/         # MainLayout、MemberLayout：不同區塊的共用版型
├── views/           # 頁面元件：IndexView、member/…
├── components/      # 可重用元件
├── service/         # 依功能分的 API 服務：IndexService、RegisterService、ChatRoomService…
├── constants/       # BACKEND_URL、API_PATHS、ROUTE_URL
├── store/           # Vuex
└── utils/
```

## 路由：巢狀版型 + 懶加載

``` javascript
const routes = [
  {
    path: ROUTE_URL.HOME,
    component: MainLayout,                       // 外層版型：Header、Footer
    children: [
      { path: '', redirect: ROUTE_URL.INDEX },
      {
        path: ROUTE_URL.INDEX,
        name: 'index',
        component: () => import('@/views/IndexView.vue')   // 懶加載：進到這頁才下載
      }
    ]
  },
  {
    path: ROUTE_URL.HOME + ROUTE_URL.MEMBER,
    component: MemberLayout,                     // 會員區另一套版型
    children: [ /* login、register、verification … */ ]
  }
];

export default createRouter({ history: createWebHistory(), routes });
```

| 路由模式 | 網址 | 注意 |
|---------|------|------|
| `createWebHistory` | `/holidayDessert/index` | 漂亮，但伺服器要把所有路徑**回退到 index.html**，否則重新整理會 404 |
| `createWebHashHistory` | `/#/index` | 不需要伺服器設定，適合放在純靜態主機或 Electron |

## API 呼叫與跨網域

前後端分屬不同的 port，就是不同的「來源（Origin）」，瀏覽器會套用**同源政策**：

``` mermaid
sequenceDiagram
    participant B as 瀏覽器（:8081）
    participant S as Spring Boot（:8080）
    B->>S: OPTIONS /api/...（預檢請求）<br>Origin: http://localhost:8081
    S->>B: Access-Control-Allow-Origin: http://localhost:8081<br>Access-Control-Allow-Credentials: true
    B->>S: 真正的請求（帶 Cookie）
```

``` javascript
// main.js：讓跨網域請求也帶上 Cookie（Session / 登入狀態）
window.axios.defaults.withCredentials = true;
```

| 做法 | 設定位置 | 適合 |
|------|---------|------|
| **後端開 CORS** | Spring `CorsConfigurationSource`，允許 `8081` 並 `allowCredentials(true)` | 前後端分開部署 |
| **開發伺服器代理** | `vue.config.js` 的 `devServer.proxy`，把 `/holidayDessert` 轉給 `8080` | 本機開發，瀏覽器以為是同源 |
| **Nginx 反向代理** | 同一網域下 `/` 給前端、`/api` 給後端 | 正式環境 |

!!! warning "`withCredentials` 的限制"

    帶 Cookie 時，後端的 `Access-Control-Allow-Origin` **不能是 `*`**，必須明確列出前端網域。

## 即時客服：STOMP over WebSocket

``` javascript
const client = new Client({ brokerURL: chatRoomService.registerStompEndpoints() });   // /ws-chat
client.onConnect = () => {
  client.subscribe(chatRoomService.subscribe() + roomUrl, msg => {                    // /topic/chat/{roomUrl}
    messages.value.push(JSON.parse(msg.body));
  });
  client.subscribe('/user/queue/errors', msg => showError(msg.body));                 // 只發給自己的錯誤
};
client.activate();

function send(text) {
  client.publish({ destination: `/app/chat/${roomUrl}`, body: JSON.stringify({ text }) });
}
```

後端 Thymeleaf 版與 Vue 版共用同一組 STOMP 端點，換前端不用改後端。

## 狀態管理：Vuex 與 Pinia

| | Vuex 4（我用的） | Pinia（Vue 官方新推薦） |
|---|-----------------|------------------------|
| 概念 | state、getters、**mutations**、actions | state、getters、actions（沒有 mutations） |
| TypeScript | 型別推導弱 | ✅ 完整推導 |
| 模組 | 巢狀 modules + namespace | 每個 store 獨立，直接 import |
| 樣板程式碼 | 多 | 少 |

!!! tip "什麼東西該放進全域狀態"

    跨頁面共用的資料（登入會員、購物車）才放進 store；只有單一頁面用的資料放在元件自己的 `ref` / `reactive` 就好。這個專案的 store 目前還是空的，資料都在各頁面自己管理，這是合理的起點。

## 打包與部署

``` bash
npm run build        # 產生 dist/，是一堆靜態檔案
```

- `dist/` 可以放在 Nginx、S3 + CloudFront，或直接放進 Spring Boot 的 `static/`
- 正式環境用 HTTPS 時，`vue.config.js` 的 `devServer.https` 指向憑證檔即可在本機測試
- CI（GitHub Actions）在 push 時自動 `npm ci` + `npm run build` 驗證能成功打包

## 優點與缺點

=== "優點"

    - **上手門檻最低**：模板語法接近 HTML，Options API 對新手友善
    - **漸進式**：可以從 CDN 引入一小塊（Vue 2 版），也能做完整 SPA
    - 官方提供 Router、狀態管理、建置工具，**選擇少、爭議少**

=== "缺點"

    - SPA 首屏需要下載 JS，**SEO 不佳**（要 SEO 時用 Nuxt 做 SSR）
    - Vue 2 → Vue 3 有破壞性變更，舊生態的套件需要升級
    - Vue CLI 已進入維護模式，新專案建議改用 **Vite**
