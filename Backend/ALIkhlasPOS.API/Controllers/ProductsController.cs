using ALIkhlasPOS.Application.Interfaces;
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

    public ProductsController(ApplicationDbContext dbContext, IBarcodeService barcodeService, IProductCacheService productCacheService)
    {
        _dbContext = dbContext;
        _barcodeService = barcodeService;
        _productCacheService = productCacheService;
    }

    public record CreateProductRequest(string Name, string? GlobalBarcode, decimal Price, decimal PurchasePrice, decimal WholesalePrice, int StockQuantity, decimal MinStockAlert = 5, string? Category = null, string? Description = null, string? ImageUrl = null);
    public record UpdateProductRequest(string Name, decimal Price, decimal PurchasePrice, decimal WholesalePrice, decimal StockQuantity, decimal MinStockAlert, string? Category, string? Description);
    public record AdjustStockRequest(decimal AdjustmentAmount, string Reason);

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
        var query = _dbContext.Products.AsQueryable();

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
            .ToListAsync(cancellationToken);

        return Ok(new { total, page, pageSize, data = products });
    }

    // GET /api/products/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetProduct(Guid id, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();
        return Ok(product);
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
        var product = new Product
        {
            Name = request.Name,
            Price = request.Price,
            PurchasePrice = request.PurchasePrice,
            WholesalePrice = request.WholesalePrice,
            StockQuantity = request.StockQuantity,
            MinStockAlert = request.MinStockAlert,
            Category = request.Category,
            Description = request.Description
        };

        if (!string.IsNullOrWhiteSpace(request.GlobalBarcode) && !_barcodeService.ValidateBarcodeFormat(request.GlobalBarcode))
            return BadRequest(new { message = "صيغة الباركود غير صحيحة." });

        if (string.IsNullOrWhiteSpace(request.GlobalBarcode))
        {
            product.GlobalBarcode = null;
            product.InternalBarcode = await _barcodeService.GenerateInternalBarcodeAsync(cancellationToken);
        }
        else
        {
            product.GlobalBarcode = request.GlobalBarcode;
            product.InternalBarcode = null;
        }

        // Check for duplicate barcodes securely before saving
        var checkingBarcodes = new List<string>();
        if (!string.IsNullOrWhiteSpace(product.GlobalBarcode)) checkingBarcodes.Add(product.GlobalBarcode);
        if (!string.IsNullOrWhiteSpace(product.InternalBarcode)) checkingBarcodes.Add(product.InternalBarcode);

        bool barcodeExists = checkingBarcodes.Any() && await _dbContext.Products.AnyAsync(p => 
            (p.GlobalBarcode != null && checkingBarcodes.Contains(p.GlobalBarcode)) ||
            (p.InternalBarcode != null && checkingBarcodes.Contains(p.InternalBarcode)), 
            cancellationToken);

        if (barcodeExists)
        {
            return BadRequest(new { message = "الباركود مستخدم بالفعل لمنتج آخر." });
        }

        _dbContext.Products.Add(product);
        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.SetProductCacheAsync(product, cancellationToken);

        return CreatedAtAction(nameof(GetProduct), new { id = product.Id }, product);
    }

    // PUT /api/products/{id} — Full update
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateProduct(Guid id, [FromBody] UpdateProductRequest request, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();

        product.Name = request.Name;
        product.Price = request.Price;
        product.PurchasePrice = request.PurchasePrice;
        product.WholesalePrice = request.WholesalePrice;
        product.StockQuantity = request.StockQuantity;
        product.MinStockAlert = request.MinStockAlert;
        product.Category = request.Category;
        product.Description = request.Description;
        product.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.SetProductCacheAsync(product, cancellationToken);

        return Ok(product);
    }

    // PATCH /api/products/{id}/stock — Stock adjustment for manual inventory count
    [HttpPatch("{id:guid}/stock")]
    public async Task<IActionResult> AdjustStock(Guid id, [FromBody] AdjustStockRequest request, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();

        product.StockQuantity += request.AdjustmentAmount;
        if (product.StockQuantity < 0) product.StockQuantity = 0;
        product.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.SetProductCacheAsync(product, cancellationToken);

        return Ok(new { product.Id, product.Name, product.StockQuantity });
    }

    // DELETE /api/products/{id}
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteProduct(Guid id, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return NotFound();

        product.IsActive = false;
        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.RemoveProductCacheAsync(product.GlobalBarcode, cancellationToken);

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

        var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowed.Contains(ext))
            return BadRequest(new { message = "صيغة الملف غير مدعومة. استخدم JPG أو PNG أو WebP." });

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
