// BackgroundService (IHostedService): builds each refresh in the passive buffer, then swaps it active.
public sealed class ProductCacheRefreshWorker : BackgroundService
{
    private readonly IProductCacheService _productCacheService;
    private readonly ILogger<ProductCacheRefreshWorker> _logger;

    public ProductCacheRefreshWorker(
        IProductCacheService productCacheService,
        ILogger<ProductCacheRefreshWorker> logger)
    {
        _productCacheService = productCacheService;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        _logger.LogInformation("Product cache background worker started (double-buffer mode).");

        // Warm the cache at startup so the first HTTP request doesn't pay the repository latency.
        await _productCacheService.RefreshAsync(stoppingToken);

        using var timer =
            new PeriodicTimer(TimeSpan.FromMinutes(3));

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await timer.WaitForNextTickAsync(stoppingToken);

                await _productCacheService.RefreshAsync(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation(
                    "Product cache background worker is stopping.");
            }
            catch (Exception ex)
            {
                // Log and continue — a single failed tick must not stop the background loop.
                _logger.LogError(
                    ex,
                    "Unexpected error in product cache background worker.");
            }
        }
    }
}