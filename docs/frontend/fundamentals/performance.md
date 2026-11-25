# 前端效能優化

## 載入效能

```
代碼分割（Code Splitting）：
  ❌ 一個巨大的 bundle.js（首屏加載所有代碼）
  ✅ 按路由分割，只加載當前頁面需要的代碼

// React（React.lazy）
const ProductPage = React.lazy(() => import('./pages/ProductPage'));
const OrderPage   = React.lazy(() => import('./pages/OrderPage'));

function App() {
    return (
        <Suspense fallback={<LoadingSpinner />}>
            <Routes>
                <Route path="/products" element={<ProductPage />} />
                <Route path="/orders"   element={<OrderPage />} />
            </Routes>
        </Suspense>
    );
}

// Vite / Webpack 動態 import
const module = await import('./heavy-module.js');

Tree Shaking（去除未使用的代碼）：
  ✅ 使用 ES Module（import/export）
  Webpack / Rollup / Vite 自動移除未引用的代碼

  ❌ import * as _ from 'lodash';     // 引入整個 lodash
  ✅ import { debounce } from 'lodash'; // 只引入需要的函式

資源優化：
  圖片：
    ✅ WebP 格式（比 JPEG 小 25~34%）
    ✅ 圖片懶加載（<img loading="lazy">）
    ✅ 響應式圖片（<picture> / srcset）
    ✅ 雪碧圖（Sprite）合併小圖示

  字型：
    ✅ 只加載需要的字重和字符集
    ✅ font-display: swap（先用系統字型，字型加載完再替換）
```

## 渲染效能

```javascript
// React 效能優化

// ① React.memo（避免不必要的重渲染）
const ProductItem = React.memo(function ProductItem({ product, onAdd }) {
    // 只有 product 或 onAdd 改變時才重渲染
    return (
        <div>
            <span>{product.name}</span>
            <button onClick={() => onAdd(product.id)}>加入購物車</button>
        </div>
    );
}, (prevProps, nextProps) => {
    // 自定義比較（返回 true = 不重渲染）
    return prevProps.product.id    === nextProps.product.id &&
           prevProps.product.price === nextProps.product.price;
});

// ② 虛擬化長列表（react-window）
import { FixedSizeList } from 'react-window';

function VirtualList({ items }) {
    const Row = ({ index, style }) => (
        <div style={style}>
            {items[index].name}
        </div>
    );

    return (
        <FixedSizeList
            height={600}       // 可視區域高度
            width={400}
            itemCount={items.length}
            itemSize={50}      // 每行高度
        >
            {Row}
        </FixedSizeList>
    );
    // 無論 items 有多少筆，只渲染可視區域的 DOM 節點
}

// ③ 防抖（debounce）/ 節流（throttle）
// 防抖：最後一次觸發後 delay ms 才執行（搜索輸入）
function useDebounce<T>(value: T, delay: number): T {
    const [debouncedValue, setDebouncedValue] = useState(value);

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedValue(value), delay);
        return () => clearTimeout(timer);
    }, [value, delay]);

    return debouncedValue;
}

// 節流：固定時間間隔最多執行一次（滾動事件）
function throttle(fn: Function, limit: number) {
    let lastTime = 0;
    return function(...args) {
        const now = Date.now();
        if (now - lastTime >= limit) {
            lastTime = now;
            fn.apply(this, args);
        }
    };
}
```

## 網路效能

```
HTTP 快取策略：
  靜態資源（JS/CSS/圖片）：
    Cache-Control: public, max-age=31536000, immutable
    搭配 Content Hash 命名（app.abc123.js）
    → 長期快取，內容改變 URL 改變

  HTML 文件：
    Cache-Control: no-cache
    → 每次驗證，確保總是最新的 HTML

預加載（Preload / Prefetch）：
  // 關鍵資源提前加載（當前頁面需要）
  <link rel="preload" href="/fonts/font.woff2" as="font" crossorigin>
  <link rel="preload" href="/api/critical-data" as="fetch" crossorigin>

  // 下一個頁面可能需要（空閒時加載）
  <link rel="prefetch" href="/pages/product.chunk.js">

  // DNS 預解析
  <link rel="dns-prefetch" href="//api.example.com">
  <link rel="preconnect" href="//api.example.com">

Service Worker（離線快取 / PWA）：
  攔截 fetch 請求
  快取資源到 Cache Storage
  網路斷開時仍能提供服務

// 簡單的 Service Worker 快取策略
self.addEventListener('fetch', event => {
    event.respondWith(
        caches.match(event.request).then(cached => {
            // 有快取 → 返回快取（同時更新快取）
            if (cached) {
                // Stale-While-Revalidate 策略
                fetch(event.request).then(response => {
                    caches.open('v1').then(cache => {
                        cache.put(event.request, response);
                    });
                });
                return cached;
            }
            // 沒快取 → 請求網路並快取
            return fetch(event.request).then(response => {
                const cloned = response.clone();
                caches.open('v1').then(cache => {
                    cache.put(event.request, cloned);
                });
                return response;
            });
        })
    );
});
```
