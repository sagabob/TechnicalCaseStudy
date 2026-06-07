# Background Service Cache Examples

Two ASP.NET Core Web API projects that demonstrate different in-memory caching strategies for product data, both refreshed by a `BackgroundService` (`IHostedService`).

| Project | Pattern | Port (HTTP) |
|---------|---------|-------------|
| **WebApi1** | Read-through cache with `IMemoryCache` | `5038` |
| **WebApi2** | Active/passive double buffer (ping-pong) | `5039` |

Both expose the same endpoint and share the same supporting types (repository, controller shape, health state, background worker). The difference is how cached data is stored and read under concurrency.

## Quick start

```powershell
# Build both projects
dotnet build BgServiceSln.slnx

# Run WebApi1 (IMemoryCache)
dotnet run --project WebApi1

# Run WebApi2 (double buffer) — use a second terminal
dotnet run --project WebApi2
```

```powershell
# Fetch products
curl http://localhost:5038/api/products   # WebApi1
curl http://localhost:5039/api/products   # WebApi2
```

Logs go to the console by default (`Default: Information` in `appsettings.json`).

---

## Shared architecture

Both projects follow the same high-level layout:

```
HTTP Request
    ↓
ProductsController          ← never calls the repository directly
    ↓
IProductCacheService        ← cache read / refresh orchestration
    ↓
ProductCacheRefreshWorker   ← IHostedService; refreshes on startup + every 3 minutes
    ↓
IProductRepository          ← scoped; fake 1.5s data source
```

| Component | Lifetime | Role |
|-----------|----------|------|
| `ProductCacheRefreshWorker` | Hosted service | Warms cache at startup; periodic refresh |
| `IProductCacheService` | Singleton | Cache logic (implementation differs per project) |
| `ProductCacheState` | Singleton | Readiness + last success/failure timestamps |
| `IProductRepository` | Scoped | Data access (resolved inside a scope per refresh) |
| `ProductCacheHealthCheck` | — | Readiness probe (registered; map with `app.MapHealthChecks("/health")` to expose) |

### Background worker behavior

- Runs **outside** the HTTP pipeline — refreshes even when there is no traffic.
- Calls `RefreshAsync` once at startup (warm-up).
- Uses `PeriodicTimer` to refresh every **3 minutes**.
- Logs and continues on failure — a bad tick does not stop the loop.

### Failure handling (both projects)

- Refresh failure does **not** evict existing good data.
- Empty product list does **not** overwrite the current cache/buffer.
- Cold start with no data yet → `503 Service Unavailable` from the controller.
- `ProductCacheState.MarkFailure()` records the failure; `IsReady` stays `true` after a prior success (health may still report healthy while serving stale data).

---

## WebApi1 — Read-through cache (`IMemoryCache`)

**Key file:** `WebApi1/Cache/ProductCacheService.cs`

### How it works

1. HTTP reads go through `IMemoryCache` under key `products:v1`.
2. On **cache miss**, `GetProductsAsync` calls `RefreshAsync` (same path as the background worker).
3. `RefreshAsync` acquires a `SemaphoreSlim` so concurrent misses don't all hit the repository (thundering herd).
4. After waiting, callers **re-check** the cache — another thread may have populated it while they waited.
5. Cache entries use `AbsoluteExpirationRelativeToNow = 30s` (shorter than the 3-minute worker interval, so on-demand refresh still occurs between ticks).

### Read path

```
GetProductsAsync
  → cache hit?  return
  → cache miss? RefreshAsync (under lock)
  → re-check cache
  → still empty? throw → controller returns 503
```

### Trade-offs

| Pros | Cons |
|------|------|
| Familiar `IMemoryCache` API | Cache miss path can block readers on the refresh lock |
| Built-in expiration | TTL and worker interval must be aligned |
| Simple single-slot model | Readers and refreshers contend on the same cache key |

---

## WebApi2 — Active/passive double buffer

**Key files:**
- `WebApi2/Cache/ProductDoubleBuffer.cs` — two slots + atomic index swap
- `WebApi2/Cache/ProductCacheService.cs` — refresh orchestration

### How it works

Two in-memory slots hold product snapshots:

```
 buffers[0]   buffers[1]
    ↑              ↑
  active        passive   ← refresh writes here, then flips active index
```

1. **Readers** call `GetActiveSnapshot()` — lock-free read of the active slot.
2. **Refresh** loads data into the **passive** slot, then atomically swaps the active index.
3. The active slot is **never mutated** during refresh — readers always get a complete snapshot.
4. `_refreshLock` in `ProductCacheService` ensures only **one writer** calls `PublishPassiveSnapshot` at a time.

### Read path

```
GetProductsAsync
  → active snapshot available?  return immediately (no lock)
  → cold start? RefreshAsync (under lock) → re-check → 503 if still empty
```

### Thread safety split

| Mechanism | Protects |
|-----------|----------|
| `Volatile.Read` / `Volatile.Write` on `_activeIndex` | Safe index flip visibility between one writer and many readers |
| `_refreshLock` (`SemaphoreSlim`) | Prevents concurrent writers racing on the passive slot |
| Try/catch in `RefreshAsync` | Exceptions don't corrupt the active buffer — swap simply doesn't happen |

`Volatile` handles **memory ordering** for the swap; it does **not** replace exception handling, empty-result checks, or single-writer enforcement.

### Trade-offs

| Pros | Cons |
|------|------|
| Lock-free reads — HTTP never waits on refresh | Two slots of memory (usually negligible) |
| No TTL/expiry confusion | Slightly more code (`ProductDoubleBuffer`) |
| Atomic swap — readers never see half-updated data | Must document/enforce single-writer contract |

---

## Side-by-side comparison

| | WebApi1 | WebApi2 |
|---|---------|---------|
| Storage | `IMemoryCache` | Two-slot `ProductDoubleBuffer` |
| Read on hit | `TryGetValue` | `GetActiveSnapshot()` |
| Read on miss | Blocks on refresh lock | Blocks only on cold start |
| Refresh | Overwrites same cache key | Writes passive, swaps active |
| Expiration | 30s absolute (+ unused 10min sliding) | None — data lives until next successful swap |
| Concurrency | Lock serializes refresh + miss path | Lock serializes refresh only; reads are lock-free |
| Extra type | — | `ProductDoubleBuffer` |

---

## Project structure

```
BgServiceSln/
├── BgServiceSln.slnx
├── README.md
├── WebApi1/
│   ├── Cache/
│   │   ├── ProductCacheService.cs      ← IMemoryCache read-through
│   │   ├── ProductCacheRefreshWorker.cs
│   │   ├── ProductCacheState.cs
│   │   └── ProductCacheHealthCheck.cs
│   ├── Controllers/ProductsController.cs
│   └── Repos/ProductRepository.cs
└── WebApi2/
    ├── Cache/
    │   ├── ProductDoubleBuffer.cs      ← active/passive swap
    │   ├── ProductCacheService.cs      ← double-buffer orchestration
    │   ├── ProductCacheRefreshWorker.cs
    │   ├── ProductCacheState.cs
    │   └── ProductCacheHealthCheck.cs
    ├── Controllers/ProductsController.cs
    └── Repos/ProductRepository.cs
```

---

## When to use which

**WebApi1 (`IMemoryCache`)** — good when:
- You want a standard framework cache with TTL/eviction policies
- Read latency during occasional cache misses is acceptable
- Simplicity matters more than lock-free reads

**WebApi2 (double buffer)** — good when:
- Read latency must stay predictable under refresh load
- You refresh large snapshots and want atomic cutover
- You're serving high read traffic and want refresh to never block readers

---

## Possible follow-ups

- Add `app.MapHealthChecks("/health")` in both `Program.cs` files
- Move magic numbers (30s TTL, 3min interval, 10s lock timeout) to `appsettings.json`
- Align WebApi1 cache TTL with the worker interval, or remove absolute expiry
- Report `Degraded` in health check when `LastFailedRefreshUtc > LastSuccessfulRefreshUtc`
