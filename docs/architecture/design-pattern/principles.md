# 設計模式六大原則

S - Single Responsibility Principle（單一職責原則）

- 一個類只做一件事
- ❌ UserService 既管用戶、又管訂單、又發郵件
- ✅ UserService / OrderService / EmailService 分開

O - Open/Closed Principle（開放封閉原則）

- 對擴展開放，對修改關閉
- 新增功能 → 新增類，不修改現有類
- ✅ 策略模式、工廠模式體現此原則

L - Liskov Substitution Principle（里氏替換原則）

- 子類可以替換父類，且程式行為不變
- ❌ 正方形繼承矩形（setWidth 會破壞正方形的約束）
- ✅ 子類只擴展功能，不改變父類已有行為的語意

I - Interface Segregation Principle（介面隔離原則）

- 介面要小而精，不要大而全
- ❌ 一個介面有 20 個方法（實作類被迫實作不需要的方法）
- ✅ 拆成多個小介面，各自只包含相關方法

D - Dependency Inversion Principle（依賴反轉原則）

- 高層模組不依賴低層模組，都依賴抽象
- ✅ Spring 的依賴注入（DI）就是實踐此原則
- ❌ OrderService 直接 new EmailService()
- ✅ OrderService 依賴 NotificationService 介面

L - Law of Demeter（迪米特法則 / 最少知識原則）

- 一個物件應該對其他物件有最少的了解
- 只和「直接朋友」溝通，不和陌生人說話
- ❌ a.getB().getC().doSomething()（跨層呼叫）
- ✅ a.doSomething()（讓 a 自己內部協調 B 和 C）
- ✅ 外觀模式（Facade）就是迪米特法則的體現
    - → 客戶端只和 Facade 溝通，不直接接觸子系統

C - Composite Reuse Principle（合成複用原則）

- 優先使用「組合 / 聚合」，而不是「繼承」來達到代碼複用
- ❌ 為了複用 A 的方法，就讓 B 繼承 A
    - → 繼承會暴露父類實作細節（破壞封裝）
    - → 父類改動會影響所有子類（高耦合）
- ✅ 讓 B 持有 A 的實例（has-a 關係）
    - → 可以在執行時動態替換（更靈活）
    - → 裝飾者模式、策略模式都體現此原則

**六大原則記憶口訣**

- 單一職責 → 一個類一件事
- 開放封閉 → 擴展不修改
- 里氏替換 → 子類能替父
- 介面隔離 → 介面要精簡
- 依賴反轉 → 依賴抽象層
- 迪米特法 → 只和朋友說
- 合成複用 → 組合優於繼承
