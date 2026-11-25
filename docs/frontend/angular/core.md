# 核心概念：元件、DI、RxJS 與 Signals

!!! abstract "本章重點"

    Angular 是內建 DI、路由、表單與 HTTP 的完整框架，它的 Service + DI 思維與 Spring 非常接近。本章介紹 standalone 元件、依賴注入、用 RxJS 處理非同步串流、用 Signals 管理狀態，以及懶加載路由。

Angular 是 Google 維護的**完整框架**：路由、表單、HTTP 客戶端、依賴注入、測試、CLI 全部內建。chinese_artwork_angular 使用 **Angular 21**，採用 standalone 元件、Signals 與 SSR。

## 和 Vue / React 的定位差異

| | Angular | Vue | React |
|---|---------|-----|-------|
| 類型 | **完整框架** | 漸進式框架 | UI 函式庫 |
| 語言 | TypeScript（強制） | JS / TS | JS / TS |
| 依賴注入 | ✅ 內建，階層式 | ❌ | ❌（用 Context） |
| 非同步模型 | **RxJS** Observable + Signals | Promise + 響應式 ref | Promise + Hook |
| 路由、表單、HTTP | 官方內建 | 官方提供 | 社群選擇 |
| 學習曲線 | 陡 | 平緩 | 中 |
| 適合 | 大型企業系統、多人協作 | 中小型、快速開發 | 各種規模、生態豐富 |

!!! info "為什麼後端工程師常覺得 Angular 很熟悉"

    Angular 的 **DI + Service + 裝飾器** 和 Spring 幾乎是同一套思維：`@Injectable` 像 `@Service`、`inject()` 像建構子注入、`providedIn: 'root'` 像 singleton Bean。

## Standalone 元件

Angular 14 之前每個元件都要宣告在 `NgModule` 裡；現在元件自己宣告依賴，**不需要 NgModule**：

``` typescript
@Component({
  selector: 'app-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, MatIconModule, CarouselModule],   // 元件自己宣告要用什麼
  templateUrl: './banner.html',
  styleUrls: ['./banner.css']
})
export class Banner implements OnInit, AfterViewInit, OnDestroy {
  @Input() bannerItems: BannerItem[] = [];      // 父元件傳入
  isBrowser: boolean;

  constructor(@Inject(PLATFORM_ID) platformId: object, private cdr: ChangeDetectorRef) {
    this.isBrowser = isPlatformBrowser(platformId);   // SSR 時不在伺服器端啟動輪播
  }
}
```

!!! tip "較新的寫法"

    Angular 17 之後官方推薦用 `input()` 取代 `@Input()`、用 `inject()` 取代建構子注入，兩者都會回傳 Signal，可以直接用在 `computed()` 中：

    ``` typescript
    readonly bannerItems = input<BannerItem[]>([]);
    private readonly platformId = inject(PLATFORM_ID);
    readonly isBrowser = isPlatformBrowser(this.platformId);
    ```

**新的控制流語法**（取代 `*ngIf`、`*ngFor`）：

``` html
@if (banners().length === 0) {
  <p>載入中…</p>
} @else {
  @for (b of banners(); track b.id) {
    <img [src]="b.imageUrl" [alt]="b.title">
  }
}
```

## 依賴注入

``` typescript
@Injectable({ providedIn: 'root' })              // 整個應用程式一個實例
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = environment.apiUrl;

  get<T>(path: string, params?: Record<string, string>) {
    return this.http.get<T>(`${this.baseUrl}${path}`, { params });
  }
}
```

chinese_artwork_angular 把 API 呼叫分成 `ApiService`（共用的 HTTP 包裝）與 `MemberService`、`SearchService`、`MenuService`（各功能），元件只注入需要的服務。

## RxJS：處理非同步串流

`HttpClient` 回傳的是 **Observable**，可以用運算子組合：

``` typescript
// 搜尋框：輸入停頓 300ms 才查詢，新的輸入會取消上一次還沒回來的請求
this.results$ = this.keyword$.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap(kw => kw ? this.searchService.search(kw) : of([])),
  catchError(() => of([]))
);
```

| 運算子 | 用途 | 與 Reactor 對照 |
|--------|------|----------------|
| `map` | 轉換 | `map` |
| `switchMap` | 換成新的 Observable，**取消舊的** | `switchMap` |
| `mergeMap` | 並行執行 | `flatMap` |
| `debounceTime` | 停頓後才發出 | `sampleTimeout` |
| `catchError` | 錯誤處理 | `onErrorResume` |

!!! tip "RxJS 和 WebFlux 是同一套思想"

    兩者都實作 ReactiveX / Reactive Streams 的概念：`Observable` ≈ `Flux`，運算子名稱也大量重疊。學會其中一個，另一個很快就能上手。

## Signals：更簡單的響應式狀態

Angular 16 加入 **Signals**，用來管理元件狀態（專案中目前只在少數地方使用，例如 `signal('chinese_artwork')` 標題；以下為建議寫法），比 RxJS 簡單，也是 Angular 走向 **Zoneless**（不靠 Zone.js 偵測變更）的基礎。

``` typescript
readonly page = signal(1);
readonly pageSize = signal(20);
readonly items = signal<Artwork[]>([]);

readonly total = computed(() => this.items().length);          // 自動追蹤依賴
readonly pageItems = computed(() =>
  this.items().slice((this.page() - 1) * this.pageSize(), this.page() * this.pageSize()));

constructor() {
  effect(() => console.log('目前第', this.page(), '頁'));      // 依賴變動時自動執行
}

next() { this.page.update(p => p + 1); }
```

| | Signals | RxJS Observable |
|---|---------|-----------------|
| 適合 | **同步狀態**：目前頁數、選中的項目、表單值 | **非同步事件流**：HTTP、輸入事件、WebSocket |
| 取值 | `page()` 直接讀 | 要 `subscribe` 或 `async` pipe |
| 互轉 | `toSignal(obs$)`、`toObservable(sig)` | |

## 路由與懶加載

``` typescript
export const routes: Routes = [
  {
    path: '',
    component: Show,                                         // 首頁版型
    children: [
      { path: ROUTE_URL.INDEX, loadComponent: () => import('./pages/index/index').then(c => c.Index) }
    ]
  },
  {
    path: '',
    component: Main,                                         // 內頁版型
    children: [
      { path: ROUTE_URL.ARTIST,  loadChildren: () => import('./pages/artist/artist.routes').then(m => m.ARTIST_ROUTES) },
      { path: ROUTE_URL.ARTWORK, loadChildren: () => import('./pages/artwork/artwork.routes').then(m => m.ARTWORK_ROUTES) }
    ]
  }
];
```

- `loadComponent`：懶加載單一元件
- `loadChildren`：懶加載一整組子路由（藝術家、作品、字典各自一包）
