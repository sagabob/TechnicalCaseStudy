using Microsoft.AspNetCore.Mvc;

// Controllers read only from the active buffer — never the repository directly.
[ApiController]
[Route("api/products")]
public sealed class ProductsController(
    IProductCacheService productCacheService,
    ILogger<ProductsController> logger) : ControllerBase
{

    [HttpGet]
    public async Task<IActionResult> GetProducts(
        CancellationToken cancellationToken)
    {
        try
        {
            var products =
                await productCacheService.GetProductsAsync(cancellationToken);

            return Ok(products);
        }
        catch (Exception ex)
        {
            logger.LogError(
                ex,
                "Failed to get products.");

            // Cache cold-start failure or unrecoverable miss → 503, not 500 (dependency unavailable).
            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new
                {
                    message = "Products are temporarily unavailable."
                });
        }
    }
}