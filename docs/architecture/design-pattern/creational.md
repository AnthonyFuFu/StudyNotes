# 創建型模式

!!! abstract "本章重點"

    創建型模式把「怎麼建立物件」與「怎麼使用物件」分開，讓系統不依賴具體類別。本章涵蓋 GoF 的 5 種創建型模式，並補充後端非常常見的物件池；單例的雙重檢查鎖定要特別注意 `volatile`。

## 單例模式（Singleton）

**目的**：確保一個類只有一個實例，並提供全局訪問點

**結構**

``` mermaid
classDiagram
    class Singleton {
        -Singleton instance$
        -Singleton()
        +getInstance()$ Singleton
        +showMessage()
    }
```

**範例**

=== "AnthonyFu-Learning 範例"

    ``` java
    // ── Singleton.java ──
    public class Singleton {
        // 私有靜態實例
        private static volatile Singleton instance;   // ⚠️ 原始碼缺少 volatile，已補上

        // 私有構造器，防止外部實例化
        private Singleton() {}

        // 提供全局訪問點 (懶加載)
        public static Singleton getInstance() {
            if (instance == null) { // 檢查實例是否已創建
                synchronized (Singleton.class) { // 確保線程安全
                    if (instance == null) {
                        instance = new Singleton();
                    }
                }
            }
            return instance;
        }

        public void showMessage() {
            System.out.println("Hello from Singleton!");
        }
    }

    // ── SingletonPattern.java ──
    public class SingletonPattern {
        public static void main(String[] args) {
            // 單例模式確保一個類只有一個實例，並提供全局訪問點。
            Singleton singleton = Singleton.getInstance();
            singleton.showMessage(); // 輸出: Hello from Singleton!
        }
    }
    ```

=== "原筆記：五種寫法比較"

    ```java
    // ❌ 懶漢式（線程不安全）
    public class Singleton {
        private static Singleton instance;

        public static Singleton getInstance() {
            if (instance == null) {
                instance = new Singleton(); // 多線程可能同時進入！
            }
            return instance;
        }
    }
    ```

    ```java
    // ✅ 方式一：餓漢式（線程安全，推薦）
    // 類加載時就初始化，不存在並發問題
    public class Singleton {
        // JVM 保證類加載是線程安全的
        private static final Singleton INSTANCE = new Singleton();

        private Singleton() {}  // 私有構造器，防止外部 new

        public static Singleton getInstance() {
            return INSTANCE;
        }
    }
    ```

    ```java
    // ✅ 方式二：雙重檢查鎖定（DCL）
    // 懶加載 + 線程安全
    public class Singleton {
        // ⚠️ 必須加 volatile！防止指令重排序！
        private static volatile Singleton instance;

        private Singleton() {}

        public static Singleton getInstance() {
            if (instance == null) {               // 第一次檢查（不加鎖，性能高）
                synchronized (Singleton.class) {
                    if (instance == null) {       // 第二次檢查（加鎖後再確認）
                        instance = new Singleton();
                        // new 分三步：① 分配記憶體 ② 初始化對象 ③ 指向記憶體地址
                        // volatile 防止 ①③② 的指令重排序
                    }
                }
            }
            return instance;
        }
    }
    ```

    ```java
    // ✅ 方式三：靜態內部類（推薦！最優雅）
    // 懶加載 + 線程安全 + 無鎖
    public class Singleton {
        private Singleton() {}

        // 內部類：只有在第一次調用 getInstance() 時才加載
        private static class SingletonHolder {
            // JVM 保證類加載的線程安全
            private static final Singleton INSTANCE = new Singleton();
        }

        public static Singleton getInstance() {
            return SingletonHolder.INSTANCE;
        }
    }
    ```

    ```java
    // ✅ 方式四：枚舉（最安全）
    // 防止反射攻擊、序列化問題
    public enum Singleton {
        INSTANCE;

        public void doSomething() {
            System.out.println("業務方法");
        }
    }

    // 使用
    Singleton.INSTANCE.doSomething();
    ```

    ```java
    // Spring 中的單例
    // Spring Bean 預設就是單例（Singleton Scope）
    @Service  // = @Component，預設 Singleton
    public class OrderService { ... }

    // 注意：Spring 單例 ≠ JVM 單例
    // Spring 單例：一個 ApplicationContext 中只有一個實例
    // JVM 單例：整個 JVM 進程只有一個實例

    // ⚠️ 單例中不能有可變的成員變數（線程不安全！）
    @Service
    public class OrderService {
        // ❌ 不安全！多個請求共用同一個 OrderService 實例
        private Order currentOrder;

        // ✅ 使用局部變數（每次調用都是新的）
        public void process() {
            Order currentOrder = new Order(); // 局部變數，線程安全
        }
    }
    ```

!!! warning "雙重檢查鎖定一定要加 volatile"

    AnthonyFu-Learning 的原始碼中 `instance` 沒有宣告 `volatile`。`new Singleton()` 實際上分成「配置記憶體 → 呼叫建構子 → 把位址指給 instance」三步，JIT 可能把後兩步**重排序**；另一條執行緒在外層 `if (instance == null)` 看到非 null，就會拿到**還沒初始化完成**的物件。加上 `volatile` 可以禁止這個重排序（見 [Java 記憶體模型](../../java/jvm/jmm.md)）。

**在 Spring 與實務中**：Spring 容器中的 Bean 預設就是 singleton，由容器保證只建立一個；實務上很少需要自己寫單例類別。

## 工廠方法模式（Factory Method）

**目的**：定義創建對象的介面，讓子類決定實例化哪個類

**結構**

``` mermaid
classDiagram
    direction LR
    class Product {
        <<interface>>
    }
    class Factory {
        <<interface>>
        +createProduct() Product
    }
    Product <|.. ConcreteProduct
    Product <|.. CarProduct
    Factory <|.. ConcreteFactory
    Factory <|.. CarFactory
    ConcreteFactory ..> ConcreteProduct : 建立
    CarFactory ..> CarProduct : 建立
```

**範例**

=== "AnthonyFu-Learning 範例"

    ``` java
    // ── Product.java ──
    public abstract class Product {
        public abstract void doSomething();
    }

    // ── ConcreteProduct.java ──
    public class ConcreteProduct extends Product {
        @Override
        public void doSomething() {
            System.out.println("ConcreteProduct do something");
        }
    }

    // ── CarProduct.java ──
    public class CarProduct extends Product {
        @Override
        public void doSomething() {
            System.out.println("CarProduct do something");
        }
    }

    // ── Factory.java ──
    public abstract class Factory {
        public abstract Product createProduct();
    }

    // ── ConcreteFactory.java ──
    public class ConcreteFactory extends Factory {
        @Override
        public Product createProduct() {
            return new ConcreteProduct();
        }
    }

    // ── CarFactory.java ──
    public class CarFactory extends Factory {
        @Override
        public Product createProduct() {
            return new CarProduct();
        }
    }

    // ── FactoryPattern.java ──
    public class FactoryPattern {
        public static void main(String[] args) {
            // 工廠方法模式用於定義一個接口，讓子類決定要創建的對象類型。
            Factory concreteFactory = new ConcreteFactory();
            Product concreteProduct = concreteFactory.createProduct();
            concreteProduct.doSomething();

            Factory carFactory = new CarFactory();
            Product carProduct = carFactory.createProduct();
            carProduct.doSomething();

        }
    }
    ```

=== "原筆記：Spring 支付工廠"

    ```java
    // 場景：不同的支付方式，有不同的支付實作

    // 1. 產品介面
    public interface PaymentHandler {
        void pay(BigDecimal amount);
        String getType();
    }

    // 2. 具體產品
    @Component
    public class AlipayHandler implements PaymentHandler {
        @Override
        public void pay(BigDecimal amount) {
            System.out.println("支付寶支付：" + amount);
        }
        @Override
        public String getType() { return "ALIPAY"; }
    }

    @Component
    public class WechatPayHandler implements PaymentHandler {
        @Override
        public void pay(BigDecimal amount) {
            System.out.println("微信支付：" + amount);
        }
        @Override
        public String getType() { return "WECHAT"; }
    }

    @Component
    public class CreditCardHandler implements PaymentHandler {
        @Override
        public void pay(BigDecimal amount) {
            System.out.println("信用卡支付：" + amount);
        }
        @Override
        public String getType() { return "CREDIT_CARD"; }
    }

    // 3. 工廠（Spring 自動注入所有實作）
    @Component
    public class PaymentHandlerFactory {

        private final Map<String, PaymentHandler> handlerMap;

        // Spring 自動注入所有 PaymentHandler 的實作
        public PaymentHandlerFactory(List<PaymentHandler> handlers) {
            this.handlerMap = handlers.stream()
                .collect(Collectors.toMap(
                    PaymentHandler::getType,
                    handler -> handler
                ));
        }

        public PaymentHandler getHandler(String paymentType) {
            PaymentHandler handler = handlerMap.get(paymentType);
            if (handler == null) {
                throw new IllegalArgumentException(
                    "不支援的支付方式：" + paymentType);
            }
            return handler;
        }
    }

    // 4. 使用
    @Service
    @RequiredArgsConstructor
    public class OrderService {

        private final PaymentHandlerFactory paymentHandlerFactory;

        public void pay(Long orderId, String paymentType, BigDecimal amount) {
            // ✅ 不需要 if-else！新增支付方式只需新增 Handler 類
            PaymentHandler handler = paymentHandlerFactory.getHandler(paymentType);
            handler.pay(amount);
        }
    }

    // ❌ 沒有工廠模式的寫法（違反開放封閉原則）
    public void pay(String paymentType, BigDecimal amount) {
        if ("ALIPAY".equals(paymentType)) {
            // 支付寶邏輯
        } else if ("WECHAT".equals(paymentType)) {
            // 微信邏輯
        } else if ("CREDIT_CARD".equals(paymentType)) {
            // 信用卡邏輯
        }
        // 每次新增支付方式，都要修改這個 if-else！❌
    }
    ```

**在 Spring 與實務中**：`BeanFactory` / `FactoryBean` 是工廠方法的典型應用；業務上常把多個實作注入成 `Map<String, Handler>`，依類型取出對應實作，取代 `if-else`。

## 抽象工廠模式（Abstract Factory）

**目的**：創建一系列相關的對象，而不指定具體類

**結構**

``` mermaid
classDiagram
    class GUIFactory {
        <<interface>>
        +createButton() Button
        +createCheckbox() Checkbox
    }
    GUIFactory <|.. WindowsFactory
    GUIFactory <|.. MacFactory
    Button <|.. WindowsButton
    Button <|.. MacButton
    Checkbox <|.. WindowsCheckbox
    Checkbox <|.. MacCheckbox
    WindowsFactory ..> WindowsButton
    WindowsFactory ..> WindowsCheckbox
    MacFactory ..> MacButton
    MacFactory ..> MacCheckbox
```

工廠方法一次建立**一種**產品；抽象工廠一次建立**一整組相關的**產品（同一個作業系統風格的按鈕 + 核取方塊），保證它們彼此搭配。

**範例**

``` java
// ── Button.java ──
interface Button {
    void click();
}

// ── Checkbox.java ──
interface Checkbox {
    void check();
}

// ── GUIFactory.java ──
interface GUIFactory {
    Button createButton();
    Checkbox createCheckbox();
}

// ── WindowsButton.java ──
class WindowsButton implements Button {
    @Override
    public void click() {
        System.out.println("Click Windows Button");
    }
}

// ── WindowsCheckbox.java ──
class WindowsCheckbox implements Checkbox {
    @Override
    public void check() {
        System.out.println("Check Windows Checkbox");
    }
}

// ── MacButton.java ──
class MacButton implements Button {
    @Override
    public void click() {
        System.out.println("Click Mac Button");
    }
}

// ── AbstractFactoryPattern.java ──
public class AbstractFactoryPattern {
    public static void main(String[] args) {
        // 抽象工廠模式用於生成一系列相關的對象，而不指定具體類型。
        // 選擇 Windows 工廠
        GUIFactory factory = new WindowsFactory();
        Button button = factory.createButton();
        Checkbox checkbox = factory.createCheckbox();
        button.click(); // 輸出: Click Windows Button
        checkbox.check(); // 輸出: Check Windows Checkbox

        // 替換為 Mac 工廠
        factory = new MacFactory();
        button = factory.createButton();
        checkbox = factory.createCheckbox();
        button.click(); // 輸出: Click Mac Button
        checkbox.check(); // 輸出: Check Mac Checkbox
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── WindowsFactory.java ──
    class WindowsFactory implements GUIFactory {
        @Override
        public Button createButton() {
            return new WindowsButton();
        }

        @Override
        public Checkbox createCheckbox() {
            return new WindowsCheckbox();
        }
    }

    // ── MacCheckbox.java ──
    class MacCheckbox implements Checkbox {
        @Override
        public void check() {
            System.out.println("Check Mac Checkbox");
        }
    }

    // ── MacFactory.java ──
    class MacFactory implements GUIFactory {
        @Override
        public Button createButton() {
            return new MacButton();
        }

        @Override
        public Checkbox createCheckbox() {
            return new MacCheckbox();
        }
    }
    ```

**在 Spring 與實務中**：跨資料庫、跨平台的元件組合，例如依設定切換 MySQL / PostgreSQL 的連線與方言實作。

## 建造者模式（Builder）

**目的**：分步驟創建複雜對象，避免大量構造器參數

**結構**

``` mermaid
classDiagram
    class ComputerBuilder {
        <<interface>>
        +buildCPU()
        +buildRAM()
        +buildStorage()
        +getComputer() Computer
    }
    ComputerBuilder <|.. GamingComputerBuilder
    ComputerDirector o-- ComputerBuilder : 依步驟呼叫
    GamingComputerBuilder ..> Computer : 組裝
```

**Director** 決定「組裝順序」，**Builder** 決定「每個零件怎麼做」。實務上更常見的是不需要 Director 的流暢寫法：`Order.builder().userId(1L).amount(100).build()`。

**範例**

``` java
// ── Computer.java ──
class Computer {
    private String CPU;
    private String GPU;
    private int RAM;
    private int storage;

    public void setCPU(String CPU) {
        this.CPU = CPU;
    }

    public void setGPU(String GPU) {
        this.GPU = GPU;
    }

    public void setRAM(int RAM) {
        this.RAM = RAM;
    }

    public void setStorage(int storage) {
        this.storage = storage;
    }

    @Override
    public String toString() {
        return "Computer [CPU=" + CPU + ", GPU=" + GPU + ", RAM=" + RAM + "GB, Storage=" + storage + "GB]";
    }
}

// ── ComputerBuilder.java ──
interface ComputerBuilder {
    void buildCPU();
    void buildGPU();
    void buildRAM();
    void buildStorage();
    Computer getComputer();
}

// ── BuilderPattern.java ──
public class BuilderPattern {
    public static void main(String[] args) {
        // 建造者模式用於分步創建複雜對象。
        ComputerBuilder builder = new GamingComputerBuilder();
        ComputerDirector director = new ComputerDirector(builder);
        Computer gamingPC = director.construct();
        System.out.println(gamingPC); // 輸出: Computer [CPU=High-end CPU, GPU=High-end GPU, RAM=32GB, Storage=1024GB]
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── GamingComputerBuilder.java ──
    class GamingComputerBuilder implements ComputerBuilder {
        private Computer computer = new Computer();

        @Override
        public void buildCPU() {
            computer.setCPU("High-end CPU");
        }

        @Override
        public void buildGPU() {
            computer.setGPU("High-end GPU");
        }

        @Override
        public void buildRAM() {
            computer.setRAM(32);
        }

        @Override
        public void buildStorage() {
            computer.setStorage(1024);
        }

        @Override
        public Computer getComputer() {
            return computer;
        }
    }

    // ── ComputerDirector.java ──
    class ComputerDirector {
        private ComputerBuilder builder;

        public ComputerDirector(ComputerBuilder builder) {
            this.builder = builder;
        }

        public Computer construct() {
            builder.buildCPU();
            builder.buildGPU();
            builder.buildRAM();
            builder.buildStorage();
            return builder.getComputer();
        }
    }
    ```

**在 Spring 與實務中**：Lombok `@Builder`、`ResponseEntity.ok().header(...).body(...)`、`UriComponentsBuilder`、`WebClient.builder()` 都是建造者模式。

## 原型模式（Prototype）

**目的**：通過複製（克隆）現有對象來創建新對象，避免重複的初始化開銷

**結構**

``` mermaid
classDiagram
    direction LR
    class Prototype {
        <<interface>>
        +clone() Prototype
    }
    Prototype <|.. ConcretePrototype
    PrototypeManager o-- Prototype : 註冊與複製
```

**淺拷貝**只複製欄位的值，物件型別的欄位仍指向同一個物件；**深拷貝**連內部物件都複製一份，修改副本不會影響原本的物件。

**範例**

=== "AnthonyFu-Learning 範例"

    ``` java
    // ── Prototype.java ──
    //原型接口
    interface Prototype {
        Prototype clone();
        void setProperty(String property);
        String getProperty();
    }

    // ── ConcretePrototype.java ──
    //具體原型
    class ConcretePrototype implements Prototype {
        private String property;

        public ConcretePrototype(String property) {
            this.property = property;
            System.out.println("ConcretePrototype created with property: " + property);
            // 模擬複雜對象創建過程
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }

        // 用於創建克隆對象的私有構造函數
        private ConcretePrototype(ConcretePrototype source) {
            this.property = source.property;
            System.out.println("ConcretePrototype cloned with property: " + property);
        }

        @Override
        public Prototype clone() {
            return new ConcretePrototype(this);
        }

        @Override
        public void setProperty(String property) {
            this.property = property;
        }

        @Override
        public String getProperty() {
            return property;
        }
    }

    // ── PrototypePattern.java ──
    //測試原型模式
    public class PrototypePattern {
        public static void main(String[] args) {
            // 創建原始對象
            Prototype original = new ConcretePrototype("Original");

            // 向管理器註冊原型
            PrototypeManager.addPrototype("original", original);

            // 使用原型創建新對象
            System.out.println("Creating clone...");
            Prototype clone1 = PrototypeManager.getPrototype("original");
            System.out.println("Clone property: " + clone1.getProperty());

            // 修改克隆對象
            clone1.setProperty("Modified Clone");
            System.out.println("Modified clone property: " + clone1.getProperty());
            System.out.println("Original property remains: " + original.getProperty());

            // 再次使用原型創建新對象
            Prototype clone2 = original.clone();
            System.out.println("Clone 2 property: " + clone2.getProperty());
        }
    }
    ```

    ??? example "其餘實作類別"

        ``` java
        // ── PrototypeManager.java ──
        //原型管理器 - 管理多個原型
        class PrototypeManager {
            private static Map<String, Prototype> prototypes = new HashMap<>();

            public static void addPrototype(String key, Prototype prototype) {
                prototypes.put(key, prototype);
            }

            public static Prototype getPrototype(String key) {
                Prototype prototype = prototypes.get(key);
                if (prototype != null) {
                    return prototype.clone();
                }
                return null;
            }
        }
        ```

=== "深拷貝 vs 淺拷貝"

    ``` java
    // ── Address.java ──
    //可序列化的引用對象
    class Address implements Serializable {
        private static final long serialVersionUID = 2L;
        private String street;
        private String city;

        public Address(String street, String city) {
            this.street = street;
            this.city = city;
        }

        // 標準的 getter/setter
        public String getStreet() {
            return street;
        }

        public void setStreet(String street) {
            this.street = street;
        }

        public String getCity() {
            return city;
        }

        public void setCity(String city) {
            this.city = city;
        }

        @Override
        public String toString() {
            return "Address [street=" + street + ", city=" + city + "]";
        }
    }

    // ── DeepCopy.java ──
    public class DeepCopy {
        public static void main(String[] args) {
            // 創建原始對象
            Address address = new Address("123 Main St", "Anytown");
            Person original = new Person("John", address);
            original.addHobby("Reading");
            original.addHobby("Cycling");

            System.out.println("原始對象: " + original);

            // 使用序列化進行深拷貝
            Person deepCopy = original.deepCopy();
            System.out.println("深拷貝對象: " + deepCopy);

            // 修改原始對象的引用字段
            original.getAddress().setStreet("456 New St");
            original.addHobby("Swimming");

            System.out.println("\n修改後的原始對象: " + original);
            System.out.println("深拷貝對象 (應保持不變): " + deepCopy);

            // 手動深拷貝測試
            Person manualCopy = original.manualDeepCopy();
            System.out.println("\n手動深拷貝對象: " + manualCopy);

            // 再次修改原始對象
            original.setName("John Updated");

            System.out.println("\n再次修改後的原始對象: " + original);
            System.out.println("手動深拷貝對象 (應保持不變): " + manualCopy);
        }
    }
    ```

    ??? example "其餘實作類別"

        ``` java
        // ── Person.java ──
        //包含引用和集合的主類
        class Person implements Serializable {
            private static final long serialVersionUID = 1L;
            private String name;
            private Address address; // 引用類型
            private List<String> hobbies; // 集合類型

            public Person(String name, Address address) {
                this.name = name;
                this.address = address;
                this.hobbies = new ArrayList<>();
            }

            // 添加愛好
            public void addHobby(String hobby) {
                hobbies.add(hobby);
            }

            // 標準的 getter/setter
            public String getName() {
                return name;
            }

            public void setName(String name) {
                this.name = name;
            }

            public Address getAddress() {
                return address;
            }

            public void setAddress(Address address) {
                this.address = address;
            }

            public List<String> getHobbies() {
                return hobbies;
            }

            @Override
            public String toString() {
                return "Person [name=" + name + ", address=" + address + ", hobbies=" + hobbies + "]";
            }

            // 使用序列化實現深拷貝
            public Person deepCopy() {
                try {
                    // 將對象寫入字節數組
                    ByteArrayOutputStream bos = new ByteArrayOutputStream();
                    ObjectOutputStream oos = new ObjectOutputStream(bos);
                    oos.writeObject(this);
                    oos.flush();

                    // 從字節數組中讀取對象
                    ByteArrayInputStream bis = new ByteArrayInputStream(bos.toByteArray());
                    ObjectInputStream ois = new ObjectInputStream(bis);
                    return (Person) ois.readObject();
                } catch (Exception e) {
                    e.printStackTrace();
                    return null;
                }
            }

            // 手動實現深拷貝 (替代方法)
            public Person manualDeepCopy() {
                // 創建新的地址對象
                Address newAddress = new Address(this.address.getStreet(), this.address.getCity());

                // 創建新的人對象
                Person newPerson = new Person(this.name, newAddress);

                // 複製愛好列表
                for (String hobby : this.hobbies) {
                    newPerson.addHobby(hobby);
                }

                return newPerson;
            }
        }
        ```

**在 Spring 與實務中**：`@Scope("prototype")` 讓每次取用都得到新實例；`BeanUtils.copyProperties` 是常見的屬性複製（淺拷貝）。

## 補充：物件池模式（Object Pool）

**目的**：預先建立一批可重複使用的物件，用完歸還而不是銷毀，避免頻繁建立昂貴的資源。不屬於 GoF 23 種，但在後端非常常見。

**結構**

``` mermaid
classDiagram
    direction LR
    class Reusable {
        <<interface>>
        +reset()
    }
    Reusable <|.. DatabaseConnection
    ObjectPool o-- DatabaseConnection : available / inUse
```

**範例**

``` java
// ── Reusable.java ──
//可重用對象接口
interface Reusable {
    void reset(); // 重置對象狀態以供重用
    void operation(); // 對象的實際操作
}

// ── DatabaseConnection.java ──
//具體可重用對象
class DatabaseConnection implements Reusable {
 private boolean isConnected;
 private String connectionId;

 public DatabaseConnection(String connectionId) {
     this.connectionId = connectionId;
     // 模擬耗時的連接創建
     System.out.println("Creating DB connection " + connectionId + "...");
     try {
         Thread.sleep(500);
     } catch (InterruptedException e) {
         e.printStackTrace();
     }
     isConnected = true;
     System.out.println("DB connection " + connectionId + " created");
 }

 @Override
 public void reset() {
     System.out.println("Resetting DB connection " + connectionId);
     // 重置對象狀態，但不斷開連接
 }

 @Override
 public void operation() {
     if (isConnected) {
         System.out.println("Using DB connection " + connectionId + " to execute query");
     } else {
         System.out.println("Connection " + connectionId + " is not available");
     }
 }

 public void close() {
     System.out.println("Closing DB connection " + connectionId);
     isConnected = false;
 }
}

// ── ObjectPoolPattern.java ──
//測試對象池模式
public class ObjectPoolPattern {
    public static void main(String[] args) throws InterruptedException {
        // 創建一個數據庫連接池
        ObjectPool<DatabaseConnection> connectionPool = new ObjectPool<>(3, id -> new DatabaseConnection("CONN-" + id));

        System.out.println("\n--- Using connections from pool ---");

        // 從池中獲取連接
        DatabaseConnection conn1 = connectionPool.acquire();
        DatabaseConnection conn2 = connectionPool.acquire();

        // 使用連接
        conn1.operation();
        conn2.operation();

        System.out.println("\n--- Releasing connection back to pool ---");

        // 歸還連接
        connectionPool.release(conn1);

        System.out.println("\n--- Acquiring connection again ---");

        // 再次獲取連接（會得到之前歸還的conn1）
        DatabaseConnection conn3 = connectionPool.acquire();
        conn3.operation();

        // 使用完畢後關閉連接池
        connectionPool.release(conn2);
        connectionPool.release(conn3);
        connectionPool.shutdown();
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── ObjectPool.java ──
    //對象池
    class ObjectPool<T extends Reusable> {
        private BlockingQueue<T> pool;
        private int maxSize;
        @SuppressWarnings("unused")
        private Creator<T> creator;

        // 創建對象的函數式接口
        interface Creator<T> {
            T create(int id);
        }

        public ObjectPool(int size, Creator<T> creator) {
            this.maxSize = size;
            this.creator = creator;
            this.pool = new LinkedBlockingQueue<>(maxSize);

            // 預先創建對象填滿池
            for (int i = 0; i < maxSize; i++) {
                pool.add(creator.create(i));
            }
        }

        // 從池中獲取對象
        public T acquire() throws InterruptedException {
            return pool.poll(3, TimeUnit.SECONDS); // 設置超時時間
        }

        // 歸還對象到池
        public void release(T obj) {
            obj.reset(); // 重置對象狀態
            try {
                pool.put(obj); // 放回對象池
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }

        // 關閉對象池
        public void shutdown() {
            for (T obj : pool) {
                if (obj instanceof DatabaseConnection) {
                    ((DatabaseConnection) obj).close();
                }
            }
            pool.clear();
        }
    }
    ```

**在 Spring 與實務中**：資料庫連線池 **HikariCP**、執行緒池 `ThreadPoolExecutor`、Apache Commons Pool；holidayDessert 搶票時的 `Semaphore(200)` 也是用「許可證池」限制同時進入的請求數。
