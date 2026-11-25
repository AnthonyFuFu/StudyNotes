# JavaScript 核心原理

## 原型鏈（Prototype Chain）

```javascript
// 每個物件都有 __proto__（原型）
// 函式有 prototype 屬性

function Animal(name) {
    this.name = name;
}

Animal.prototype.speak = function() {
    return `${this.name} 發出聲音`;
};

function Dog(name, breed) {
    Animal.call(this, name); // 繼承屬性
    this.breed = breed;
}

// 繼承原型
Dog.prototype = Object.create(Animal.prototype);
Dog.prototype.constructor = Dog;

Dog.prototype.bark = function() {
    return `${this.name} 汪汪叫`;
};

const dog = new Dog('小黑', '拉布拉多');

// 原型鏈：
// dog → Dog.prototype → Animal.prototype → Object.prototype → null
//
// dog.__proto__                   === Dog.prototype
// dog.__proto__.__proto__         === Animal.prototype
// dog.__proto__.__proto__.__proto__ === Object.prototype
// dog.__proto__.__proto__.__proto__.__proto__ === null

console.log(dog.speak()); // 小黑 發出聲音（從 Animal.prototype 找到）
console.log(dog.bark());  // 小黑 汪汪叫（從 Dog.prototype 找到）

// ES6 Class（語法糖，底層還是原型鏈）
class AnimalES6 {
    constructor(name) {
        this.name = name;
    }
    speak() {
        return `${this.name} 發出聲音`;
    }
}

class DogES6 extends AnimalES6 {
    constructor(name, breed) {
        super(name);          // 呼叫父類 constructor
        this.breed = breed;
    }
    bark() {
        return `${this.name} 汪汪叫`;
    }
}
```

## 閉包（Closure）

```javascript
// 閉包 = 函式 + 其詞法環境（可以存取外部函式的變數）

function makeCounter(initialValue = 0) {
    let count = initialValue; // 私有變數（外部無法直接訪問）

    return {
        increment() { return ++count; },
        decrement() { return --count; },
        getCount()  { return count; }
    };
}

const counter = makeCounter(10);
console.log(counter.increment()); // 11
console.log(counter.increment()); // 12
console.log(counter.getCount());  // 12
// count 無法從外部直接訪問！→ 數據私有化

// 閉包的常見陷阱（var vs let）
// ❌ 問題：var 沒有塊級作用域
for (var i = 0; i < 3; i++) {
    setTimeout(() => console.log(i), 100);
}
// 輸出：3, 3, 3（都是同一個 i，循環已結束）

// ✅ 解法一：let（塊級作用域，每次循環獨立）
for (let i = 0; i < 3; i++) {
    setTimeout(() => console.log(i), 100);
}
// 輸出：0, 1, 2

// ✅ 解法二：IIFE（立即執行函式，每次傳入當前 i）
for (var i = 0; i < 3; i++) {
    ((j) => setTimeout(() => console.log(j), 100))(i);
}
// 輸出：0, 1, 2

// 閉包實際應用：函式柯里化（Currying）
function multiply(a) {
    return function(b) {
        return a * b; // 記住了 a
    };
}

const double = multiply(2);
const triple = multiply(3);
console.log(double(5)); // 10
console.log(triple(5)); // 15
```

## 非同步：Promise / async-await

```javascript
// Promise 三種狀態：pending → fulfilled / rejected

// 手動實作 Promise.all（面試常考）
function promiseAll(promises) {
    return new Promise((resolve, reject) => {
        const results = [];
        let completedCount = 0;

        if (promises.length === 0) {
            resolve([]);
            return;
        }

        promises.forEach((promise, index) => {
            Promise.resolve(promise)
                .then(result => {
                    results[index] = result;
                    completedCount++;
                    if (completedCount === promises.length) {
                        resolve(results); // 全部完成才 resolve
                    }
                })
                .catch(reject); // 任一失敗立即 reject
        });
    });
}

// async / await 錯誤處理
async function fetchUserData(userId) {
    try {
        const user    = await userService.findById(userId);
        const orders  = await orderService.findByUser(userId);
        return { user, orders };
    } catch (error) {
        console.error('查詢失敗', error);
        throw error;
    }
}

// 並行執行（不要串行 await，浪費時間！）
async function fetchParallel(userId) {
    // ❌ 串行（總耗時 = 各自耗時相加）
    const user   = await userService.findById(userId);   // 等 user 完成
    const orders = await orderService.findByUser(userId); // 才開始查 order

    // ✅ 並行（總耗時 = 最慢的那個）
    const [user2, orders2] = await Promise.all([
        userService.findById(userId),
        orderService.findByUser(userId)
    ]);

    return { user: user2, orders: orders2 };
}
```
