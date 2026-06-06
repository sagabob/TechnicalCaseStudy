using Microsoft.Extensions.Diagnostics.HealthChecks;

// Readiness check: lets load balancers / orchestrators wait until the active buffer has loaded at least once.
public sealed class ProductCacheHealthCheck : IHealthCheck
{
    private readonly ProductCacheState _cacheState;

    public ProductCacheHealthCheck(ProductCacheState cacheState)
    {
        _cacheState = cacheState;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        if (!_cacheState.IsReady)
        {
            return Task.FromResult(
                HealthCheckResult.Unhealthy("Product cache is not ready."));
        }

        return Task.FromResult(
            HealthCheckResult.Healthy(
                $"Active product buffer ready. Last refresh: {_cacheState.LastSuccessfulRefreshUtc}"));
    }
}