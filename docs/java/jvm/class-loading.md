# 類加載機制

## 類加載的完整流程（7 個步驟）

``` mermaid
block-beta
    columns 6
    space:1 lk["連接 Linking"]:3 space:2
    load["載入<br>Loading"] verify["驗證<br>Verify"] prepare["準備<br>Prepare"] resolve["解析<br>Resolve"] init["初始化<br>Init"] use["使用 → 卸載<br>Use / Unload"]
    classDef title fill:transparent,stroke-dasharray:4 4
    class lk title
```

`.class` 文件依序經過：載入 → **連接（驗證 → 準備 → 解析）** → 初始化 → 使用 → 卸載。

### 每個階段詳解：

```java
public class Demo {
    public static int value = 100;
    public static final String NAME = "Java";

    static {
        System.out.println("靜態初始化塊執行！");
        value = 200;
    }
}
```

- ① 載入（Loading）：
    - ✅ 根據類的全限定名找到 .class 文件
    - ✅ 將二進制字節流加載到記憶體
    - ✅ 在方法區建立類的元資訊
    - ✅ 在堆中建立 java.lang.Class 對象

- ② 驗證（Verification）：
    - ✅ 文件格式驗證（魔數 CAFEBABE 開頭？）
    - ✅ 元數據驗證（是否繼承了 final 類？）
    - ✅ 字節碼驗證（指令是否合法？）
    - ✅ 符號引用驗證（引用的類/方法存在嗎？）

- ③ 準備（Preparation）：
    - ✅ 為靜態變數分配記憶體，設置「零值」（不是初始值！）

- value = 0    ← 零值（不是 100！）
- NAME = null  ← 零值（但 final 常量例外！）

- ⚠️ 例外：static final 基本類型/字串常量 → 直接賦值
- NAME = "Java" ← final 常量直接賦值（編譯期常量）

- ④ 解析（Resolution）：
    - ✅ 將常量池中的符號引用替換為直接引用
    - 符號引用：com/example/Demo（字串符號）
    - 直接引用：記憶體地址（真實指針）

- ⑤ 初始化（Initialization）：
    - ✅ 執行類的靜態代碼（&lt;clinit> 方法）
    - ✅ 按照代碼順序執行靜態賦值和靜態代碼塊

- value = 100  ← 靜態賦值
- System.out.println("靜態初始化塊執行！") ← 靜態代碼塊
- value = 200  ← 靜態代碼塊中的賦值

- 最終 value = 200

- ⑥ 使用（Using）：正常使用類和對象

- ⑦ 卸載（Unloading）：類不再使用，GC 回收

### 初始化的觸發條件（主動引用）：

```java
// ✅ 以下情況會觸發類初始化：
Demo demo = new Demo();          // 1. new 對象
int v = Demo.value;              // 2. 訪問靜態變數（非 final 常量）
Demo.staticMethod();             // 3. 調用靜態方法
Class.forName("com.example.Demo"); // 4. 反射
new Child();                     // 5. 子類初始化時，父類先初始化

// ❌ 以下情況「不會」觸發初始化（被動引用）：
int v = Demo.NAME;               // 訪問 final 常量 → 不觸發
Demo[] arr = new Demo[10];       // 建立陣列 → 不觸發
```

## 雙親委派模型（Parent Delegation Model）

**類加載器層次結構**

``` mermaid
flowchart LR
    CUS["Custom"] -- parent --> APP["Application"] -- parent --> EXT["Extension"] -- parent --> BOOT["Bootstrap"]
```

| 類加載器 | 實現 | 載入路徑 | 載入內容 |
|---------|------|---------|---------|
| **Bootstrap ClassLoader**（啟動類加載器） | C++，Java 看不到 | `jre/lib/rt.jar` | JDK 核心類（`String`、`Object` …） |
| **Extension ClassLoader**（擴展類加載器） | Java | `jre/lib/ext/*.jar` | JDK 擴展類 |
| **Application ClassLoader**（應用程序類加載器） | Java | classpath | 你寫的類 |
| **Custom ClassLoader**（自定義類加載器） | Java | 自訂 | 自訂來源（加密、網路等） |

### 雙親委派流程：

``` mermaid
sequenceDiagram
    autonumber
    participant App as AppClassLoader
    participant Ext as ExtClassLoader
    participant Boot as BootstrapClassLoader
    Note over App,Boot: 載入 com.example.Demo
    App->>Ext: 先委派給父加載器
    Ext->>Boot: 再委派給父加載器
    Boot-->>Ext: rt.jar 找不到
    Note over Ext: 自己嘗試 → 找不到
    Ext-->>App: 返回「找不到」
    Note over App: 自己載入 → 找到了 ✅
    Note over App,Boot: 載入 java.lang.String
    App->>Ext: 委派
    Ext->>Boot: 委派
    Note over Boot: 在 rt.jar 找到 ✅<br>使用 Bootstrap 載入的 String
```

### 為什麼要有雙親委派？

```java
// 安全性：你自己寫了一個 java.lang.String
package java.lang;
public class String {
    static {
        System.out.println("我入侵了 JVM！"); // 惡意代碼
    }
}
// 雙親委派保護：Bootstrap 從 rt.jar 找到了真正的 String.class
// 你的惡意 String 永遠不會被載入！✅
```

### 自定義 ClassLoader：

```java
public class CustomClassLoader extends ClassLoader {

    private final String classPath;

    public CustomClassLoader(String classPath) {
        this.classPath = classPath;
    }

    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        byte[] classData = loadClassData(name);
        if (classData == null) {
            throw new ClassNotFoundException(name);
        }
        return defineClass(name, classData, 0, classData.length);
    }

    private byte[] loadClassData(String className) {
        String path = classPath + "/" +
                      className.replace('.', '/') + ".class";
        try (InputStream is  = new FileInputStream(path);
             ByteArrayOutputStream bos = new ByteArrayOutputStream()) {

            byte[] buffer = new byte[1024];
            int len;
            while ((len = is.read(buffer)) != -1) {
                bos.write(buffer, 0, len);
            }
            return bos.toByteArray();

        } catch (IOException e) {
            return null;
        }
    }
}
```

### 打破雙親委派：

```java
// 打破方式：重寫 loadClass() 方法（不調用 super）
public class BreakParentDelegation extends ClassLoader {

    @Override
    public Class<?> loadClass(String name) throws ClassNotFoundException {
        // 對自己的類，直接自己載入（打破委派）
        if (name.startsWith("com.example")) {
            return findClass(name);   // 跳過父加載器！
        }
        // 其他類還是走雙親委派（JDK 核心類必須走）
        return super.loadClass(name);
    }
}

// 打破雙親委派的典型案例：
// 1. JDBC（SPI 機制）
// 2. Tomcat（隔離不同 Web 應用的類）
// 3. OSGi（模塊化框架）
```
