using System.Text.Json;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;

namespace ALIkhlasPOS.Infrastructure.Services;

public class ProductCacheService : IProductCacheService
{
    private readonly IDistributedCache _cache;
    private readonly ApplicationDbContext _dbContext;

    public ProductCacheService(IDistributedCache cache, ApplicationDbContext dbContext)
    {
        _cache = cache;
        _dbContext = dbContext;
    }

    public async Task<Product?> GetProductByBarcodeAsync(string barcode, CancellationToken cancellationToken = default)
    {
        var cacheKey = $"Product_{barcode}";
        
        // 1. Check Redis Cache First
        var cachedProductXml = await _cache.GetStringAsync(cacheKey, cancellationToken);
        if (!string.IsNullOrEmpty(cachedProductXml))
        {
            return JsonSerializer.Deserialize<Product>(cachedProductXml);
        }

        // 2. Fallback to Database if not cached
        var product = await _dbContext.Products
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.GlobalBarcode == barcode || p.InternalBarcode == barcode, cancellationToken);

        // 3. Set Cache if found
        if (product != null)
        {
            await SetProductCacheAsync(product, cancellationToken);
        }

        return product;
    }

    public async Task SetProductCacheAsync(Product product, CancellationToken cancellationToken = default)
    {
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(12) // Cache duration
        };

        var productJson = JsonSerializer.Serialize(product);
        
        // Cache by Global Barcode if available
        if (!string.IsNullOrEmpty(product.GlobalBarcode))
        {
            await _cache.SetStringAsync($"Product_{product.GlobalBarcode}", productJson, options, cancellationToken);
        }
        
        // Cache by Internal Barcode if available
        if (!string.IsNullOrEmpty(product.InternalBarcode))
        {
            await _cache.SetStringAsync($"Product_{product.InternalBarcode}", productJson, options, cancellationToken);
        }
    }

    public async Task PreloadValidProductsAsync(CancellationToken cancellationToken = default)
    {
        // Zero Latency Initialization Strategy
        // Fetch products that are active/with stock and load them into Redis
        var products = await _dbContext.Products
            .AsNoTracking()
            .Where(p => p.StockQuantity > 0 || p.Price > 0)
            .ToListAsync(cancellationToken);

        foreach (var product in products)
        {
            await SetProductCacheAsync(product, cancellationToken);
        }
    }

    public async Task RemoveProductCacheAsync(string barcode, CancellationToken cancellationToken = default)
    {
        await _cache.RemoveAsync($"Product_{barcode}", cancellationToken);
    }
}
