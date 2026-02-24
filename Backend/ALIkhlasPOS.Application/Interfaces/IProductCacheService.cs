namespace ALIkhlasPOS.Application.Interfaces;

using ALIkhlasPOS.Domain.Entities;

public interface IProductCacheService
{
    Task<Product?> GetProductByBarcodeAsync(string barcode, CancellationToken cancellationToken = default);
    Task SetProductCacheAsync(Product product, CancellationToken cancellationToken = default);
    Task PreloadValidProductsAsync(CancellationToken cancellationToken = default);
    Task RemoveProductCacheAsync(string barcode, CancellationToken cancellationToken = default);
}
