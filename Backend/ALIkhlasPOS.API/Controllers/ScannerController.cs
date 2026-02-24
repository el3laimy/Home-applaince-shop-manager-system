using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class ScannerController : ControllerBase
{
    private readonly IProductCacheService _productCacheService;

    public ScannerController(IProductCacheService productCacheService)
    {
        _productCacheService = productCacheService;
    }

    [HttpGet("{barcode}")]
    public async Task<IActionResult> ScanBarcode(string barcode, CancellationToken cancellationToken)
    {
        var product = await _productCacheService.GetProductByBarcodeAsync(barcode, cancellationToken);

        if (product == null)
            return NotFound(new { message = "Product not found." });

        // Zero Latency Search Response
        return Ok(new
        {
            product.Id,
            product.Name,
            Barcode = !string.IsNullOrEmpty(product.GlobalBarcode) ? product.GlobalBarcode : product.InternalBarcode,
            Price = product.Price,
            StockQuantity = product.StockQuantity
        });
    }
}
