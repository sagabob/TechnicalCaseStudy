// Shared mutable state read by the cache service, background worker, and health check.
public sealed class ProductCacheState
{
    public bool IsReady { get; private set; }
    public DateTimeOffset? LastSuccessfulRefreshUtc { get; private set; }
    public DateTimeOffset? LastFailedRefreshUtc { get; private set; }

    public void MarkSuccess()
    {
        IsReady = true;
        LastSuccessfulRefreshUtc = DateTimeOffset.UtcNow;
    }

    public void MarkFailure()
    {
        // IsReady stays true after a prior success — health may still report Healthy while serving stale data.
        LastFailedRefreshUtc = DateTimeOffset.UtcNow;
    }
}