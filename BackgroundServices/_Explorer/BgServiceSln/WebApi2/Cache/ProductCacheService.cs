// Double-buffered cache: reads are lock-free against the active buffer; refresh writes to passive then atomically swaps.
public sealed class ProductCacheService(
    ProductDoubleBuffer doubleBuffer,
    IServiceProvider serviceProvider,
    ProductCacheState cacheState,
    ILogger<ProductCacheService> logger) : IProductCacheService
{
    // Serializes refresh so only one thread calls PublishPassiveSnapshot at a time.
    // HTTP reads never wait on this lock — unlike WebApi1, only the refresher acquires it.
    private readonly SemaphoreSlim _refreshLock = new(1, 1);

    public async Task<IReadOnlyList<Product>> GetProductsAsync(CancellationToken cancellationToken)
    {
        var products = doubleBuffer.GetActiveSnapshot();
        if (products is not null)
        {
            return products;
        }

        // Cold start: no active snapshot yet — block once until the first refresh completes.
        await RefreshAsync(cancellationToken);

        products = doubleBuffer.GetActiveSnapshot();
        if (products is not null)
        {
            return products;
        }

        throw new InvalidOperationException("Product cache could not be loaded.");
    }

    public async Task RefreshAsync(CancellationToken cancellationToken)
    {
        var isLockAcquired = await _refreshLock.WaitAsync(TimeSpan.FromSeconds(10), cancellationToken);
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
                // Don't swap in empty data — readers keep serving the current active buffer.
                logger.LogWarning("Product refresh returned zero products. Keeping active buffer.");
                return;
            }

            var passiveIndex = doubleBuffer.PassiveIndex;
            doubleBuffer.PublishPassiveSnapshot(passiveIndex, products);

            cacheState.MarkSuccess();
            logger.LogInformation(
                "Products cache refreshed into passive buffer {PassiveIndex} and swapped active, {Count} products",
                passiveIndex,
                products.Count);
        }
        catch (OperationCanceledException)
        {
            logger.LogInformation("Product cache refresh was cancelled.");
        }
        catch (Exception ex)
        {
            cacheState.MarkFailure();

            // Refresh failure does not swap buffers — the active snapshot remains available to readers.
            logger.LogError(
                ex,
                "Product cache refresh failed. Active buffer will remain available.");
        }
        finally
        {
            _refreshLock.Release();
        }
    }
}
