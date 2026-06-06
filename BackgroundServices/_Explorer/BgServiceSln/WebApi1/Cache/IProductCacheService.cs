public interface IProductCacheService
{
    Task<IReadOnlyList<Product>> GetProductsAsync(
        CancellationToken cancellationToken);

    Task RefreshAsync(
        CancellationToken cancellationToken);
}