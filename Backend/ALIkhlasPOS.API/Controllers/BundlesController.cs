using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class BundlesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public BundlesController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public record CreateBundleRequest(string Name, Guid ParentProductId, List<BundleItemRequest> SubProducts);
    public record BundleItemRequest(Guid SubProductId, int QuantityRequired, decimal DiscountAmount);

    [HttpPost]
    public async Task<IActionResult> CreateBundle([FromBody] CreateBundleRequest request, CancellationToken cancellationToken)
    {
        var parentProduct = await _dbContext.Products.FindAsync(new object[] { request.ParentProductId }, cancellationToken);
        if (parentProduct == null)
            return BadRequest("Parent product (the Set) not found.");

        var bundles = new List<Bundle>();

        foreach (var item in request.SubProducts)
        {
            var subProduct = await _dbContext.Products.FindAsync(new object[] { item.SubProductId }, cancellationToken);
            if (subProduct == null)
                return BadRequest($"Sub product with ID {item.SubProductId} not found.");

            bundles.Add(new Bundle
            {
                Name = request.Name,
                ParentProductId = parentProduct.Id,
                SubProductId = subProduct.Id,
                QuantityRequired = item.QuantityRequired,
                DiscountAmount = item.DiscountAmount
            });
        }

        _dbContext.Bundles.AddRange(bundles);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new { message = "Bundle created successfully", bundleCount = bundles.Count });
    }

    [HttpGet("{parentProductId:guid}")]
    public async Task<IActionResult> GetBundleDetails(Guid parentProductId, CancellationToken cancellationToken)
    {
        var bundleItems = await _dbContext.Bundles
            .Include(b => b.SubProduct)
            .Where(b => b.ParentProductId == parentProductId)
            .Select(b => new
            {
                b.SubProductId,
                SubProductName = b.SubProduct!.Name,
                b.QuantityRequired,
                b.DiscountAmount
            })
            .ToListAsync(cancellationToken);

        if (!bundleItems.Any())
            return NotFound("No bundle found for this product.");

        return Ok(bundleItems);
    }
}
