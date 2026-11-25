# 實戰：React 19 + TypeScript

!!! abstract "專案：fu-clan-management-system"

    傅氏宗親會管理系統，以 **Electron** 包成桌面程式，畫面用 **React 19 + TypeScript + Vite + Ant Design 6**，資料存在本機 SQLite（sql.js）。這一章聚焦在 React 的寫法；Electron 的架構見 [Electron 桌面應用](../electron/index.md)。

## 技術選擇

| 分類 | 工具 | 為什麼 |
|------|------|-------|
| UI 框架 | React 19 | 生態最大、元件化 |
| 語言 | TypeScript 5 | 與 Electron 主程序**共用型別**，IPC 參數對不上時編譯就失敗 |
| 元件庫 | Ant Design 6 | 表格、表單、日期選擇、樹狀圖等後台元件齊全 |
| 路由 | react-router-dom 7（`HashRouter`） | Electron 以 `file://` 載入，`BrowserRouter` 找不到路由 |
| 狀態 | React Context | 系統設定、近期活動提醒這類全域資料，不需要 Redux |
| 建置 | Vite | 開發伺服器秒開、HMR 快 |
| 測試 | Vitest + Testing Library | 與 Vite 共用設定 |
| 品質 | ESLint + Prettier | CI 中檢查 |

## 自訂 Hook：把「讀取資料」抽出來

每個頁面都要處理 loading、錯誤訊息、重新查詢；與其每頁重寫，不如抽成 Hook：

``` typescript
// 包裝讀取類操作（與 useAsyncAction 包裝寫入類操作成對）
export function useApiQuery<T>(
  query: (api: ElectronAPI) => Promise<T>,
  deps: DependencyList,
  { enabled = true, errorPrefix = '讀取資料失敗' }: ApiQueryOptions = {}
): ApiQueryResult<T> {
  const { message } = App.useApp();
  const [data, setData] = useState<T>();
  const [loading, setLoading] = useState(enabled);
  const [version, setVersion] = useState(0);

  // query 通常是每次 render 都重新建立的箭頭函式，放在 ref 裡，避免讓 effect 每次都重跑
  const queryRef = useRef(query);
  queryRef.current = query;

  useEffect(() => {
    if (!enabled) return;
    let stale = false;                       // 競態條件保護
    setLoading(true);
    queryRef.current(window.electronAPI!)
      .then(result => { if (!stale) setData(result); })
      .catch(err => { if (!stale) message.error(`${errorPrefix}：${errorMessage(err)}`); })
      .finally(() => { if (!stale) setLoading(false); });
    return () => { stale = true; };          // deps 改變時，舊的查詢結果直接丟掉
  }, [...deps, enabled, version]);

  return { data, loading, reload: () => setVersion(v => v + 1) };
}
```

``` typescript
// 頁面中使用
const { data: members, loading, reload } = useApiQuery(
  api => api.listMembers({ page, keyword, generation }),
  [page, keyword, generation]
);
```

!!! tip "這個 Hook 解決的三個問題"

    1. **競態條件**：快速切換篩選條件時，比較慢回來的舊結果不會蓋掉新結果（`stale` 旗標）
    2. **重新查詢保留舊資料**：`data` 不先清空，畫面不會閃成空白
    3. **錯誤一定被處理**：不會出現沒人接的 Promise rejection

## React 19 的新東西

| 功能 | 用途 |
|------|------|
| **Actions**（`useActionState`、`useFormStatus`） | 表單送出的 pending / error 狀態由 React 管理 |
| **`use()`** | 在 render 中讀取 Promise 或 Context，可以放在條件式裡 |
| **`useOptimistic`** | 樂觀更新：先改畫面，失敗再還原 |
| **React Compiler** | 自動 memo，大幅減少手寫 `useMemo` / `useCallback` |
| `ref` 可以直接當 prop 傳 | 不再需要 `forwardRef` |

## 測試

``` typescript
it('搜尋姓名後只顯示符合的成員', async () => {
  window.electronAPI = mockElectronAPI({ listMembers: async () => [member('傅一'), member('傅二')] });
  render(<App><MembersPage /></App>);

  await userEvent.type(screen.getByPlaceholderText('姓名或電話'), '傅一');
  expect(await screen.findByText('傅一')).toBeInTheDocument();
});
```

Testing Library 的原則：**用使用者看得到的方式找元素**（文字、placeholder、role），不要依賴 class 或內部 state，重構時測試才不會跟著壞。

## 優點與缺點

=== "優點"

    - **一切都是 JavaScript**：JSX 讓條件、迴圈、組合都用語言本身表達
    - **自訂 Hook** 讓邏輯重用非常自然
    - 生態最大：元件庫、狀態管理、測試工具選擇最多
    - 同一套知識可以延伸到 React Native、Electron

=== "缺點"

    - **只是 UI 函式庫**：路由、狀態、資料取得都要自己選，新手容易選擇困難
    - `useEffect` 的依賴陣列、閉包陳舊值（stale closure）是常見錯誤來源
    - 沒有 Compiler 時，效能優化要自己判斷何時 memo
