# React 核心原理

## Virtual DOM 與 Diff 算法

```
Virtual DOM 是什麼？
  用 JavaScript 物件描述真實 DOM 的輕量副本

  真實 DOM：
  <div id="app">
    <h1>Hello</h1>
    <p>World</p>
  </div>

  Virtual DOM：
  {
    type: 'div',
    props: { id: 'app' },
    children: [
      { type: 'h1', props: {}, children: ['Hello'] },
      { type: 'p',  props: {}, children: ['World'] }
    ]
  }

為什麼需要 Virtual DOM？
  直接操作真實 DOM 代價很高（觸發重排/重繪）
  Virtual DOM 在記憶體中比較差異（Diff）
  只對真實 DOM 做最小量的更新

Diff 算法三大策略：

① 同層比較（只比較同一層級，不跨層級）
  不同類型的元素 → 直接替換整棵子樹
  相同類型的元素 → 更新屬性，繼續比較子元素

② key 屬性（列表優化）
  相同 key → 認為是同一個元素，只更新屬性
  不同 key → 創建新元素，銷毀舊元素

  ❌ 不要用 index 作為 key（列表增刪時會錯誤匹配）
  ✅ 使用唯一且穩定的 id 作為 key

③ 組件類型
  同類型組件 → 更新 props，不重建
  不同類型組件 → 銷毀舊組件，創建新組件
```

## Fiber 架構（React 16+）

**Fiber 解決的問題**

**React 15 的 Stack Reconciler**

- → 遞迴同步更新 DOM，一旦開始無法中斷
- → 大量更新時，主線程被長時間佔用
- → 動畫卡頓 / 用戶輸入無響應

**Fiber 的解決方式**

- 將渲染工作拆成小單元（Fiber Node）
- 每個 Fiber Node 對應一個 React 元素
- 利用 requestIdleCallback 在瀏覽器空閒時執行
- 可以中斷、恢復、重用工作

**Fiber 兩個階段**

- ① Reconciliation（協調，可中斷）：
    - 遍歷 Fiber Tree，找出需要更新的節點
    - 標記副作用（新增 / 更新 / 刪除）
    - 可以被更高優先級的工作中斷

- ② Commit（提交，不可中斷）：
    - 將 Reconciliation 的結果一次性應用到真實 DOM
    - 執行 useEffect / useLayoutEffect

**優先級調度（Concurrent Mode）**

- 不同類型的更新有不同優先級
- 用戶輸入（最高優先級）→ 立即響應
- 動畫 → 高優先級
- 數據加載 → 低優先級
- → 高優先級任務可以打斷低優先級任務

## Hooks 深度

```javascript
// ════════════════════════════════
// useState - 狀態管理
// ════════════════════════════════
function Counter() {
    const [count, setCount] = useState(0);

    // ✅ 使用函式更新（基於前一個值）
    const increment = () => setCount(prev => prev + 1);

    // ❌ 直接用 count（閉包陷阱，並發模式下可能不正確）
    const wrongIncrement = () => setCount(count + 1);

    return <button onClick={increment}>{count}</button>;
}

// ════════════════════════════════
// useEffect - 副作用處理
// ════════════════════════════════
function UserProfile({ userId }) {
    const [user, setUser] = useState(null);

    useEffect(() => {
        let cancelled = false; // 防止競態條件

        async function fetchUser() {
            const data = await userService.findById(userId);
            if (!cancelled) { // 組件未卸載才更新狀態
                setUser(data);
            }
        }

        fetchUser();

        // 清理函式（組件卸載或 userId 改變時執行）
        return () => { cancelled = true; };

    }, [userId]); // 依賴陣列：userId 改變時重新執行

    return <div>{user?.name}</div>;
}

// ════════════════════════════════
// useCallback / useMemo - 效能優化
// ════════════════════════════════
function ProductList({ products, onAddToCart }) {
    // useMemo：快取計算結果（只在依賴改變時重新計算）
    const expensiveProducts = useMemo(() => {
        return products.filter(p => p.price > 1000);
    }, [products]); // products 改變才重新計算

    // useCallback：快取函式（只在依賴改變時創建新函式）
    const handleAddToCart = useCallback((productId) => {
        onAddToCart(productId);
    }, [onAddToCart]); // onAddToCart 改變才創建新函式

    return (
        <ul>
            {expensiveProducts.map(product => (
                <ProductItem
                    key={product.id}
                    product={product}
                    onAdd={handleAddToCart}
                />
            ))}
        </ul>
    );
}

// ════════════════════════════════
// 自定義 Hook（Custom Hook）
// ════════════════════════════════
function useFetch<T>(url: string) {
    const [data,    setData]    = useState<T | null>(null);
    const [loading, setLoading] = useState(true);
    const [error,   setError]   = useState<Error | null>(null);

    useEffect(() => {
        let cancelled = false;

        setLoading(true);
        setError(null);

        fetch(url)
            .then(res => res.json())
            .then(data => {
                if (!cancelled) {
                    setData(data);
                    setLoading(false);
                }
            })
            .catch(err => {
                if (!cancelled) {
                    setError(err);
                    setLoading(false);
                }
            });

        return () => { cancelled = true; };
    }, [url]);

    return { data, loading, error };
}

// 使用自定義 Hook
function UserList() {
    const { data: users, loading, error } = useFetch<User[]>('/api/users');

    if (loading) return <Spinner />;
    if (error)   return <ErrorMessage error={error} />;

    return (
        <ul>
            {users?.map(user => <li key={user.id}>{user.name}</li>)}
        </ul>
    );
}
```

## 狀態管理

```javascript
// ════════════════════════════════
// Context API（輕量狀態共享）
// ════════════════════════════════
const UserContext = createContext<User | null>(null);

function UserProvider({ children }) {
    const [user, setUser] = useState<User | null>(null);

    const login  = async (credentials) => {
        const user = await authService.login(credentials);
        setUser(user);
    };
    const logout = () => setUser(null);

    return (
        <UserContext.Provider value={{ user, login, logout }}>
            {children}
        </UserContext.Provider>
    );
}

// 自定義 Hook 封裝
function useUser() {
    const context = useContext(UserContext);
    if (!context) throw new Error('useUser 必須在 UserProvider 內使用');
    return context;
}

// ════════════════════════════════
// Zustand（輕量狀態管理，推薦）
// ════════════════════════════════
import { create } from 'zustand';

interface CartState {
    items:      CartItem[];
    addItem:    (item: CartItem) => void;
    removeItem: (id: string) => void;
    clearCart:  () => void;
    total:      () => number;
}

const useCartStore = create<CartState>((set, get) => ({
    items: [],

    addItem: (item) => set(state => ({
        items: [...state.items, item]
    })),

    removeItem: (id) => set(state => ({
        items: state.items.filter(item => item.id !== id)
    })),

    clearCart: () => set({ items: [] }),

    total: () => get().items.reduce((sum, item) =>
        sum + item.price * item.quantity, 0
    ),
}));

// 使用
function Cart() {
    const { items, removeItem, total } = useCartStore();

    return (
        <div>
            {items.map(item => (
                <CartItem
                    key={item.id}
                    item={item}
                    onRemove={() => removeItem(item.id)}
                />
            ))}
            <div>總計：{total()}</div>
        </div>
    );
}
```
