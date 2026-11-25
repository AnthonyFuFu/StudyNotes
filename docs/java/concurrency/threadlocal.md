# ThreadLocal

## 底層原理

```
ThreadLocal 解決的問題：
  每個線程都需要有自己獨立的變數副本
  如：數據庫連線、用戶上下文、MDC 日誌追蹤

底層結構：

每個 Thread 物件內部有一個 ThreadLocalMap：
  Thread.threadLocals = ThreadLocalMap

ThreadLocalMap 是一個特殊的 HashMap：
  key   = ThreadLocal 物件（弱引用）
  value = 存入的值

Thread1.threadLocals:
  [ThreadLocal@001] → "User-Alice"
  [ThreadLocal@002] → Connection@A

Thread2.threadLocals:
  [ThreadLocal@001] → "User-Bob"
  [ThreadLocal@002] → Connection@B

每個線程有自己的 Map → 自然隔離！
```

```java
// ThreadLocal 使用
public class UserContext {

    private static final ThreadLocal<UserInfo> CURRENT_USER =
        new ThreadLocal<>();

    public static void setUser(UserInfo user) {
        CURRENT_USER.set(user);
    }

    public static UserInfo getUser() {
        return CURRENT_USER.get();
    }

    // ⚠️ 必須清除！否則線程池中的線程會殘留舊資料
    public static void clear() {
        CURRENT_USER.remove();
    }
}

// 在 Filter 中使用
@Component
public class UserContextFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain)
            throws ServletException, IOException {
        try {
            UserInfo user = extractUserFromToken(request);
            UserContext.setUser(user);
            chain.doFilter(request, response);
        } finally {
            UserContext.clear(); // ⚠️ 必須在 finally 清除！
        }
    }
}

// 業務層直接取用，不需要傳參
@Service
public class OrderService {
    public Order createOrder(OrderRequest request) {
        UserInfo currentUser = UserContext.getUser(); // 直接取得當前用戶
        // ...
    }
}
```

## 記憶體洩漏問題

```
為什麼會洩漏？

ThreadLocalMap 的 Entry：
  key   = WeakReference<ThreadLocal>（弱引用）
  value = Object（強引用）

當 ThreadLocal 物件沒有外部強引用時：
  GC 會回收 ThreadLocal 物件（key 變為 null）
  但 value 仍有強引用，GC 無法回收！
  → 記憶體洩漏！

                   GC 可以回收
ThreadLocal ref ────X───→ ThreadLocal 物件
                             ↑ 弱引用
Thread → ThreadLocalMap → Entry
                             ↓ 強引用（洩漏！）
                           value 物件（無法回收）

在線程池場景更嚴重：
  線程池的線程長期存活
  → 線程的 ThreadLocalMap 長期存在
  → value 永遠不會被 GC 回收
  → 記憶體一直洩漏！

解決方案：
  ✅ 使用完後立即呼叫 remove()（最重要！）
  ✅ 在 try-finally 中呼叫 remove()
  ✅ ThreadLocal 宣告為 static final（確保有強引用）
```
