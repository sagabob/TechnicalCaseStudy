using Microsoft.Extensions.Caching.Memory;

// Read-through cache: HTTP reads from IMemoryCache; refresh is triggered on miss or by the background worker.
public class ProductCacheService(
    IMemoryCache cache,
    IServiceProvider serviceProvider,
    ProductCacheState cacheState,
    ILogger<ProductCacheService> logger):IProductCacheService
{
    private const string CacheKey = "products:v1";

    // Serializes refresh so concurrent cache misses don't all hit the repository at once (thundering herd).
    private static readonly SemaphoreSlim RefreshLock = new(1, 1);

    public async Task<IReadOnlyList<Product>> GetProductsAsync(CancellationToken cancellationToken)
    {
        if (cache.TryGetValue(CacheKey, out IReadOnlyList<Product>? products) && products is not null)
        {
            return products;
        }

        // Cache miss: fall back to refresh (same path the background worker uses).
        await RefreshAsync(cancellationToken);

        // Re-check after waiting — another caller may have populated the cache while we waited on the lock.
        if (cache.TryGetValue(CacheKey, out products))
        {
            return products!;
        }

        throw new InvalidOperationException(
            "Product cache could not be loaded.");
    }

    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        var isLockAcquired = await RefreshLock.WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
        if (!isLockAcquired)
        {
            logger.LogWarning("Failed to acquire lock for refreshing products cache");
            return;
        }

        try
        {
            // Singleton cannot take IProductRepository directly (it's scoped) — create a scope per refresh.
            using var scope = serviceProvider.CreateScope();

            var productRepository = scope.ServiceProvider.GetRequiredService<IProductRepository>();
            var products = await productRepository.GetProductsAsync(cancellationToken);

            if (products.Count == 0)
            {
                // Don't overwrite good data with an empty result; stale cache is better than no cache.
                logger.LogWarning(
                    "Product refresh returned zero products. Keeping old cache.");

                return;
            }

            // NOTE: absolute expiry (30s) is shorter than the worker interval (3 min), so on-demand refresh
            // still runs between scheduled ticks. Align these values in production or drop absolute expiry.
            cache.Set(CacheKey, products, new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(30),
                SlidingExpiration = TimeSpan.FromMinutes(10),
                Priority = CacheItemPriority.High
            });

            cacheState.MarkSuccess();
            logger.LogInformation("Products cache refreshed successfully, {Count} products", products.Count);
        }
        catch (OperationCanceledException)
        {
            logger.LogInformation(
                "Product cache refresh was cancelled.");
        }
        catch (Exception ex)
        {
            cacheState.MarkFailure();

            // Refresh failure does not evict the cache — callers keep serving the last good snapshot.
            logger.LogError(
                ex,
                "Product cache refresh failed. Existing cache will remain available.");
        }
        finally
        {
            RefreshLock.Release();
        }
    }
}