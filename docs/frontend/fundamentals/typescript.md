# TypeScript 深度

!!! abstract "本章重點"

    TypeScript 在編譯期就能找出型別錯誤，讓大型前端專案更好維護。本章介紹型別系統的基礎、泛型，以及 `Partial`、`Pick`、`Omit`、`Record` 等實用工具型別。

## 類型系統

```typescript
// 基本類型
let name:    string  = 'Alice';
let age:     number  = 25;
let active:  boolean = true;
let nothing: null    = null;
let undef:   undefined = undefined;

// 聯合類型（Union）
type ID = string | number;
let id: ID = 'user-123';
id = 456; // 也可以

// 字面量類型（精確值）
type Direction = 'LEFT' | 'RIGHT' | 'UP' | 'DOWN';
type StatusCode = 200 | 201 | 400 | 401 | 403 | 404 | 500;

// 介面（Interface）vs 類型別名（Type Alias）
interface User {
    id:       number;
    name:     string;
    email?:   string;      // 可選屬性
    readonly role: string; // 只讀屬性
}

// interface 可以繼承和合併
interface AdminUser extends User {
    permissions: string[];
}

// 同名 interface 自動合併（Declaration Merging）
interface User { age?: number; }
// User 現在有 id, name, email, role, age

// Type Alias 更靈活（支援聯合 / 交叉類型）
type ApiResponse<T> = {
    success: boolean;
    data:    T;
    message: string;
};

// 交叉類型（Intersection）= 合併
type AdminUser2 = User & { permissions: string[] };
```

## 泛型（Generics）

```typescript
// 泛型函式
function identity<T>(value: T): T {
    return value;
}

const str = identity<string>('Hello'); // string
const num = identity<number>(42);      // number
// TypeScript 可以推斷類型，不必明確指定

// 泛型介面
interface Repository<T> {
    findById(id: number): Promise<T>;
    findAll(): Promise<T[]>;
    save(entity: T): Promise<T>;
    delete(id: number): Promise<void>;
}

// 實作
class UserRepository implements Repository<User> {
    async findById(id: number): Promise<User> { /* ... */ }
    async findAll(): Promise<User[]>           { /* ... */ }
    async save(user: User): Promise<User>      { /* ... */ }
    async delete(id: number): Promise<void>    { /* ... */ }
}

// 泛型約束（Constraint）
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
    return obj[key];
}

const user: User = { id: 1, name: 'Alice', role: 'admin' };
const userName = getProperty(user, 'name');  // string ✅
// getProperty(user, 'invalid');             // ❌ 編譯錯誤！

// 泛型類別
class Stack<T> {
    private items: T[] = [];

    push(item: T): void     { this.items.push(item); }
    pop(): T | undefined    { return this.items.pop(); }
    peek(): T | undefined   { return this.items[this.items.length - 1]; }
    isEmpty(): boolean      { return this.items.length === 0; }
    size(): number          { return this.items.length; }
}

const numberStack = new Stack<number>();
numberStack.push(1);
numberStack.push(2);
console.log(numberStack.pop()); // 2
```

## 實用工具類型（Utility Types）

```typescript
interface User {
    id:       number;
    name:     string;
    email:    string;
    password: string;
    role:     string;
    createdAt: Date;
}

// Partial<T>：所有屬性變為可選（更新請求常用）
type UpdateUserRequest = Partial<User>;
// { id?: number; name?: string; email?: string; ... }

// Required<T>：所有屬性變為必填
type RequiredUser = Required<User>;

// Readonly<T>：所有屬性變為只讀
type ReadonlyUser = Readonly<User>;

// Pick<T, K>：只取部分屬性（響應 DTO 常用）
type UserPublicInfo = Pick<User, 'id' | 'name' | 'role'>;
// { id: number; name: string; role: string; }

// Omit<T, K>：排除部分屬性（排除敏感欄位）
type UserWithoutPassword = Omit<User, 'password'>;
// { id, name, email, role, createdAt } - 沒有 password

// Record<K, V>：key-value 映射
type RolePermissions = Record<string, string[]>;
const permissions: RolePermissions = {
    'admin': ['read', 'write', 'delete'],
    'user':  ['read'],
};

// Exclude<T, U>：從聯合類型中排除
type Status  = 'pending' | 'active' | 'inactive' | 'deleted';
type Visible = Exclude<Status, 'deleted'>;
// 'pending' | 'active' | 'inactive'

// Extract<T, U>：從聯合類型中取交集
type ActiveStatus = Extract<Status, 'active' | 'pending'>;
// 'active' | 'pending'

// ReturnType<T>：取函式返回類型
async function getUser() { return new User(); }
type GetUserReturn = ReturnType<typeof getUser>; // Promise<User>

// Parameters<T>：取函式參數類型
function createOrder(userId: number, items: string[]): void {}
type CreateOrderParams = Parameters<typeof createOrder>;
// [userId: number, items: string[]]

// 實際應用：型別安全的 API 響應
type ApiResponse<T> = {
    success: true;
    data: T;
} | {
    success: false;
    error: string;
    code: string;
};

function handleResponse<T>(response: ApiResponse<T>): T {
    if (response.success) {
        return response.data; // TypeScript 知道這裡有 data
    }
    throw new Error(response.error); // TypeScript 知道這裡有 error
}
```
