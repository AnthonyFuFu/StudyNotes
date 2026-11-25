# Vue 核心原理

!!! abstract "本章重點"

    Vue 的核心是響應式系統：資料改變時畫面自動更新。本章比較 Vue 2 的 `Object.defineProperty` 與 Vue 3 的 Proxy 實作差異，並說明 Composition API 如何讓邏輯更容易重用。

## 響應式系統對比（Vue 2 vs Vue 3）

```javascript
// Vue 2：Object.defineProperty（有缺陷）
const data = { count: 0, items: [] };

Object.defineProperty(data, 'count', {
    get() {
        // 依賴收集（Watcher 訂閱）
        return value;
    },
    set(newVal) {
        value = newVal;
        // 觸發更新（通知所有 Watcher）
    }
});

// Vue 2 的缺陷：
// ❌ 無法偵測屬性新增（必須用 Vue.set）
//    data.newProp = 'value' → 不響應！
//    Vue.set(data, 'newProp', 'value') → ✅

// ❌ 無法偵測陣列 index 直接修改
//    data.items[0] = 'new' → 不響應！
//    需要用 push/pop/splice 等變異方法

// Vue 3：Proxy（完全解決 Vue 2 的問題）
const reactiveData = new Proxy(data, {
    get(target, key, receiver) {
        // 依賴追蹤
        track(target, key);
        return Reflect.get(target, key, receiver);
    },
    set(target, key, value, receiver) {
        const result = Reflect.set(target, key, value, receiver);
        // 觸發更新
        trigger(target, key);
        return result;
    },
    // 還可以攔截 deleteProperty、has 等操作
    deleteProperty(target, key) {
        const result = Reflect.deleteProperty(target, key);
        trigger(target, key);
        return result;
    }
});

// Vue 3 的優勢：
// ✅ 偵測屬性新增/刪除
// ✅ 偵測陣列 index 修改
// ✅ 惰性響應（深層屬性只在訪問時才響應化）
// ✅ 效能更好（不需要初始化時遍歷所有屬性）
```

## Composition API

```javascript
// Options API（Vue 2 風格）
// 問題：相關邏輯分散在 data / methods / computed / watch
export default {
    data() {
        return { count: 0, user: null };
    },
    methods: {
        increment() { this.count++; },
        async fetchUser() { /* 邏輯 */ }
    },
    computed: {
        doubleCount() { return this.count * 2; }
    },
    watch: {
        count(newVal) { console.log(newVal); }
    }
};

// Composition API（Vue 3）
// 優勢：相關邏輯集中在一起，更好的可複用性
import { ref, reactive, computed, watch, onMounted } from 'vue';

// 可複用的邏輯（類比 React Custom Hook）
function useCounter(initialValue = 0) {
    const count = ref(initialValue);

    const doubleCount = computed(() => count.value * 2);

    function increment() { count.value++; }
    function decrement() { count.value--; }
    function reset()     { count.value = initialValue; }

    watch(count, (newVal, oldVal) => {
        console.log(`count 從 ${oldVal} 變為 ${newVal}`);
    });

    return { count, doubleCount, increment, decrement, reset };
}

function useUser(userId) {
    const user    = ref(null);
    const loading = ref(false);
    const error   = ref(null);

    async function fetchUser() {
        loading.value = true;
        try {
            user.value = await userService.findById(userId);
        } catch (e) {
            error.value = e;
        } finally {
            loading.value = false;
        }
    }

    onMounted(fetchUser);

    return { user, loading, error, refetch: fetchUser };
}

// 在組件中使用
export default {
    setup() {
        const { count, doubleCount, increment } = useCounter(0);
        const { user, loading } = useUser(1);

        return { count, doubleCount, increment, user, loading };
    }
};

// <script setup> 語法糖（Vue 3.2+，更簡潔）
```
