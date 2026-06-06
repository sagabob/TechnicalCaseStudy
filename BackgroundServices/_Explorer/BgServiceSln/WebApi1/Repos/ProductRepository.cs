public class ProductRepository(ILogger<ProductRepository> logger) : IProductRepository
{
    public async Task<IReadOnlyList<Product>> GetProductsAsync(CancellationToken cancellationToken = default)
    {

        logger.LogInformation("Getting products from fake data");
        await Task.Delay(1500, cancellationToken);

        logger.LogInformation("Products got from fake data after 1500ms");
        
        return new List<Product>
        {
            new(1, "Product 1", 100),
            new(2, "Product 2", 200),
            new(3, "Product 3", 300),
        };
    }
}