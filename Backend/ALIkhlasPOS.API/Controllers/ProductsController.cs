using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Microsoft.AspNetCore.Authorization.Authorize]
public class ProductsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IBarcodeService _barcodeService;
    private readonly IProductCacheService _productCacheService;
    private readonly IAccountingService _accountingService;
    private readonly IProductService _productService;

    public ProductsController(ApplicationDbContext dbContext, IBarcodeService barcodeService, IProductCacheService productCacheService, IAccountingService accountingService, IProductService productService)
    {
        _dbContext = dbContext;
        _barcodeService = barcodeService;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
        _productService = productService;
    }

    // DTOs defined at the bottom of the file
    // BUG-13: Use int for stock quantity, not decimal
    public record CreateProductRequest(string Name, string? Description, string? CategoryName, decimal Price, decimal PurchasePrice, decimal WholesalePrice, int StockQuantity, int? MinStockLevel, string? GlobalBarcode, string? InternalBarcode, decimal? VatRate, bool GenerateBarcode = false);
    public record UpdateProductRequest(string Name, string? Description, string? CategoryName, decimal Price, decimal PurchasePrice, decimal WholesalePrice, int StockQuantity, int? MinStockLevel, string? GlobalBarcode, string? InternalBarcode, decimal? VatRate);
    public record AdjustStockRequest(int AdjustmentQuantity, string Reason, decimal? CostPerUnit);
    // Lookup by barcode response type
    public record ProductLookupResponse(string Id, string Name, decimal Price, decimal WholesalePrice, string Barcode, int StockQuantity, decimal VatRate, string? ImageUrl);

    // GET /api/products/next-barcode — Preview the next auto-generated internal barcode
    [HttpGet("next-barcode")]
    public async Task<IActionResult> GetNextBarcode(CancellationToken cancellationToken)
    {
        var barcode = await _barcodeService.GenerateInternalBarcodeAsync(cancellationToken);
        return Ok(new { barcode });
    }

    // GET /api/products — List all with optional search, category filter, pagination
    [HttpGet]
    public async Task<IActionResult> GetAllProducts(
        [FromQuery] string? search = null,
        [FromQuery] string? category = null,
        [FromQuery] bool? lowStock = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Products.Where(p => p.IsActive).AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(p =>
                p.Name.Contains(search) ||
                p.GlobalBarcode.Contains(search) ||
                (p.InternalBarcode != null && p.InternalBarcode.Contains(search)) ||
                (p.Category != null && p.Category.Contains(search)));

        if (!string.IsNullOrWhiteSpace(category))
            query = query.Where(p => p.Category == category);

        if (lowStock == true)
            query = query.Where(p => p.StockQuantity <= p.MinStockAlert);

        var total = await query.CountAsync(cancellationToken);
        var products = await query
            .OrderBy(p => p.Category).ThenBy(p => p.Name)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(p => new
            {
                p.Id, p.Name, p.Description, p.Category,
                p.Price, p.PurchasePrice, p.WholesalePrice,
                p.StockQuantity, p.MinStockAlert,
                p.GlobalBarcode, p.InternalBarcode,
                p.ImageUrl, p.IsActive, p.CreatedAt, p.UpdatedAt
            })
            .ToListAsync(cancellationToken);

        return Ok(new { total, page, pageSize, data = products });
    }

    // GET /api/products/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetProduct(Guid id, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();
        return Ok(new
        {
            product.Id, product.Name, product.Description, product.Category,
            product.Price, product.PurchasePrice, product.WholesalePrice,
            product.StockQuantity, product.MinStockAlert,
            product.GlobalBarcode, product.InternalBarcode,
            product.ImageUrl, product.IsActive, product.CreatedAt, product.UpdatedAt
        });
    }

    // GET /api/products/barcode/{barcode} — Used by POS Scanner (hits Redis cache first)
    [HttpGet("barcode/{barcode}")]
    public async Task<IActionResult> GetProductByBarcode(string barcode, CancellationToken cancellationToken)
    {
        var product = await _productCacheService.GetProductByBarcodeAsync(barcode, cancellationToken);
        if (product == null) return NotFound(new { message = $"لا يوجد منتج بهذا الباركود: {barcode}" });
        return Ok(product);
    }

    // GET /api/products/categories — For dropdown filters
    [HttpGet("categories")]
    public async Task<IActionResult> GetCategories(CancellationToken cancellationToken)
    {
        var categories = await _dbContext.Products
            .Where(p => p.Category != null)
            .Select(p => p.Category!)
            .Distinct()
            .OrderBy(c => c)
            .ToListAsync(cancellationToken);
        return Ok(categories);
    }

    // POST /api/products — Create new product
    [HttpPost]
    public async Task<IActionResult> CreateProduct([FromBody] CreateProductRequest request, CancellationToken cancellationToken)
    {
        var dto = new CreateProductDto(request.Name, request.Description, request.CategoryName, request.Price, request.PurchasePrice, request.WholesalePrice, request.StockQuantity, request.MinStockLevel, request.GlobalBarcode, request.InternalBarcode, request.VatRate, request.GenerateBarcode);
        var response = await _productService.CreateProductAsync(dto, cancellationToken);
        
        if (!response.Success) return BadRequest(new { message = response.Message });
        
        return CreatedAtAction(nameof(GetProduct), new { id = response.Product!.Id }, response.Product);
    }

    // PUT /api/products/{id} — Full update
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateProduct(Guid id, [FromBody] UpdateProductRequest request, CancellationToken cancellationToken)
    {
        var dto = new UpdateProductDto(request.Name, request.Description, request.CategoryName, request.Price, request.PurchasePrice, request.WholesalePrice, request.StockQuantity, request.MinStockLevel, request.GlobalBarcode, request.InternalBarcode, request.VatRate);
        var createdBy = User.Identity?.Name ?? User.Claims.FirstOrDefault(c => c.Type == System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "System";
        
        var response = await _productService.UpdateProductAsync(id, dto, createdBy, cancellationToken);
        
        if (!response.Success) 
        {
            if (response.Message == "Product not found") return NotFound();
            return BadRequest(new { message = response.Message });
        }
        
        var product = response.Product!;
        return Ok(new
        {
            product.Id, product.Name, product.Description, product.Category,
            product.Price, product.PurchasePrice, product.WholesalePrice,
            product.StockQuantity, product.MinStockAlert,
            product.GlobalBarcode, product.InternalBarcode,
            product.ImageUrl, product.IsActive, product.CreatedAt, product.UpdatedAt
        });
    }

    // PATCH /api/products/{id}/stock — Stock adjustment for manual inventory count
    [HttpPatch("{id:guid}/stock")]
    public async Task<IActionResult> AdjustStock(Guid id, [FromBody] AdjustStockRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.Identity?.Name ?? User.Claims.FirstOrDefault(c => c.Type == System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "System";
        var dto = new AdjustStockDto(request.AdjustmentQuantity, request.Reason, request.CostPerUnit);
        
        var response = await _productService.AdjustStockAsync(id, dto, createdBy, cancellationToken);
        
        if (!response.Success)
        {
            if (response.Message == "Product not found") return NotFound();
            return BadRequest(new { message = response.Message });
        }
        
        return Ok(new { response.Product!.Id, response.Product.Name, response.Product.StockQuantity });
    }

    // GET /api/products/{id}/stock-adjustments — Get history of manual stock adjustments (Legacy)
    [HttpGet("{id:guid}/stock-adjustments")]
    public async Task<IActionResult> GetStockAdjustments(Guid id, CancellationToken cancellationToken)
    {
        var adjustments = await _dbContext.Set<StockAdjustment>()
            .Where(a => a.ProductId == id)
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => new
            {
                a.Id, a.ProductId, a.Type, a.QuantityAdjusted,
                a.Cost, a.Reason, a.CreatedBy, a.CreatedAt
            })
            .ToListAsync(cancellationToken);
            
        return Ok(adjustments);
    }

    // GET /api/products/{id}/stock-movements — Get full history of stock movements (Sales, Purchases, Returns, Adjustments)
    [HttpGet("{id:guid}/stock-movements")]
    public async Task<IActionResult> GetStockMovements(Guid id, CancellationToken cancellationToken)
    {
        var movements = await _dbContext.StockMovements
            .Where(m => m.ProductId == id)
            .OrderByDescending(m => m.CreatedAt)
            .Select(m => new
            {
                m.Id,
                m.Type,
                TypeLabel = m.Type == StockMovementType.Sale ? "مبيعات" :
                            m.Type == StockMovementType.Purchase ? "مشتريات" :
                            m.Type == StockMovementType.ReturnSale ? "مرتجع مبيعات" :
                            m.Type == StockMovementType.ReturnPurchase ? "مرتجع مشتريات" :
                            m.Type == StockMovementType.Adjustment ? "تسوية" : "رصيد افتتاحي",
                m.Quantity,
                m.BalanceAfter,
                m.ReferenceId,
                m.ReferenceNumber,
                m.Notes,
                m.CreatedBy,
                m.CreatedAt
            })
            .ToListAsync(cancellationToken);
            
        return Ok(movements);
    }

    // DELETE /api/products/{id}
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteProduct(Guid id, CancellationToken cancellationToken)
    {
        var success = await _productService.DeleteProductAsync(id, cancellationToken);
        if (!success) return NotFound();
        return NoContent();
    }

    // POST /api/products/{id}/image — Upload product image (saved to wwwroot/uploads/products/)
    [HttpPost("{id:guid}/image")]
    public async Task<IActionResult> UploadProductImage(Guid id, IFormFile file, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();

        if (file == null || file.Length == 0)
            return BadRequest(new { message = "لم يتم إرسال ملف." });

        // Max 5 MB
        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { message = "حجم الصورة يجب أن يكون أقل من 5 ميجابايت." });

        // ── Magic Number Validation (binary signature check) ──
        // Prevents uploading disguised malicious files with renamed extensions
        var allowedSignatures = new Dictionary<string, byte[][]>
        {
            { ".jpg",  new[] { new byte[] { 0xFF, 0xD8, 0xFF } } },
            { ".jpeg", new[] { new byte[] { 0xFF, 0xD8, 0xFF } } },
            { ".png",  new[] { new byte[] { 0x89, 0x50, 0x4E, 0x47 } } },
            { ".webp", new[] { new byte[] { 0x52, 0x49, 0x46, 0x46 } } }, // RIFF header
        };

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedSignatures.ContainsKey(ext))
            return BadRequest(new { message = "صيغة الملف غير مدعومة. استخدم JPG أو PNG أو WebP." });

        // Read first 8 bytes and compare with known magic numbers
        using var headerStream = file.OpenReadStream();
        var header = new byte[8];
        await headerStream.ReadAsync(header, 0, 8, cancellationToken);
        headerStream.Position = 0; // Reset for later copy

        var validSigs = allowedSignatures[ext];
        bool magicMatch = validSigs.Any(sig => 
            header.Length >= sig.Length && header.Take(sig.Length).SequenceEqual(sig));

        if (!magicMatch)
            return BadRequest(new { message = "محتوى الملف لا يتطابق مع صيغة الصورة. تأكد من أن الملف صورة حقيقية." });

        var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "products");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{id}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        await using var stream = System.IO.File.Create(filePath);
        await file.CopyToAsync(stream, cancellationToken);

        product.ImageUrl = $"/uploads/products/{fileName}";
        product.UpdatedAt = DateTime.UtcNow;
        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.SetProductCacheAsync(product, cancellationToken);

        return Ok(new { imageUrl = product.ImageUrl });
    }
}
