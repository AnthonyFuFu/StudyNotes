# 漸進增強：在伺服器頁面上加互動

!!! abstract "本章重點"

    本章說明一個頁面裡各項技術的分工、jQuery 命令式與 Vue 宣告式更新的差別，最後比較混合架構與 Vue 3 SPA 的取捨。

伺服器端模板負責「第一次把頁面送出來」，之後的互動（表格分頁、即時更新、聊天室）交給瀏覽器端的 JavaScript。holidayDessert 的頁面就是這種混合架構：**Thymeleaf 出頁面，jQuery / Vue 2 處理互動，STOMP 處理即時訊息**。

## 一個頁面裡的分工

``` mermaid
flowchart LR
    TH["Thymeleaf<br>版型、選單、權限"] --> HTML["完整 HTML"]
    HTML --> JQ["jQuery<br>DataTables、表單、AJAX"]
    HTML --> VUE["Vue 2（CDN）<br>局部區塊資料綁定"]
    HTML --> WS["STOMP.js + SockJS<br>客服聊天室"]
```

| 技術 | 負責 | 我的使用 |
|------|------|---------|
| **Thymeleaf** | 版型、側欄、權限判斷、首屏資料 | 前台、後台所有頁面 |
| **jQuery** | DOM 操作、AJAX、套件生態 | 後台表格（DataTables）、表單、Sparkline 圖表 |
| **Vue 2（CDN 引入）** | 某個區塊需要「資料改了畫面就更新」 | 會員登入、註冊、驗證頁 |
| **Axios** | 呼叫 REST API | 搭配 Vue 取資料 |
| **STOMP.js + SockJS** | WebSocket 即時訊息 | 客服聊天室 |

## jQuery：命令式更新

``` javascript
$('#btnSearch').on('click', function () {
  $.get('/holidayDessert/admin/order/list', { status: $('#status').val() })
    .done(function (rows) {
      const $tbody = $('#orderTable tbody').empty();
      rows.forEach(r => $tbody.append(`<tr><td>${escapeHtml(r.orderNo)}</td><td>${r.total}</td></tr>`));
    });
});
```

**命令式**：自己找到 DOM、自己決定怎麼改。頁面簡單時最快，狀態一多就容易出現「資料和畫面不一致」。

!!! warning "自己拼 HTML 要小心 XSS"

    用字串組 HTML 時，後端來的資料一定要先跳脫（或改用 `.text()`）。Thymeleaf 的 `th:text`、Vue 的 `{{ }}` 都會自動處理，jQuery 不會。

## Vue 2 從 CDN 引入：宣告式更新

不需要建置工具，在 Thymeleaf 頁面裡直接掛載一個 Vue 實例：

``` html
<div id="app">
  <input v-model="email" placeholder="Email">
  <p v-if="error" class="error">{{ error }}</p>
  <button :disabled="loading" @click="register">註冊</button>
</div>

<script src="vue.js"></script>
<script src="axios.min.js"></script>
<script>
new Vue({
  el: '#app',
  data: { email: '', error: '', loading: false },
  methods: {
    async register() {
      this.loading = true;
      try {
        await axios.post('/holidayDessert/member/register', { email: this.email });
      } catch (e) {
        this.error = e.response?.data?.message ?? '註冊失敗';
      } finally {
        this.loading = false;
      }
    }
  }
});
</script>
```

**宣告式**：只改資料（`this.error = ...`），畫面由 Vue 自動更新。這是從 jQuery 過渡到 SPA 最平滑的一步。

## 從混合架構走向前後端分離

holidayDessert 後來另外做了 Vue 3 SPA 版的前台（[holiday_dessert_vue](../vue/vue3-spa.md)），後端只提供 API。兩種架構並存，正好可以比較：

| | Thymeleaf + jQuery / Vue 2 | Vue 3 SPA |
|---|---------------------------|-----------|
| 首屏 | ✅ 快，SEO 好 | 需要下載 JS 才看得到內容 |
| 換頁 | 整頁重新載入 | 前端路由，不重新載入 |
| 部署 | 一個 JAR | 前端靜態檔 + 後端 API，兩套部署 |
| 跨網域 | 不需要 | 需要處理 CORS 或反向代理 |
| 團隊分工 | 前後端綁在一起 | 前後端可以各自開發、各自發版 |
| 適合 | 後台管理系統、內容型網站 | 互動多的前台、要同時支援 App |
