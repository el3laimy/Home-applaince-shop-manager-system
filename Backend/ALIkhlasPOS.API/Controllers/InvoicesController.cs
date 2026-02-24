using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InvoicesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IProductCacheService _productCacheService;

    public InvoicesController(ApplicationDbContext dbContext, IProductCacheService productCacheService)
    {
        _dbContext = dbContext;
        _productCacheService = productCacheService;
    }

    // ── Request DTOs ─────────────────────────────────────────────────────────
    public record ScanItemRequest(string Barcode, int Quantity = 1);

    public record InvoiceCreateRequest(
        List<ScanItemRequest> ScannedItems,
        PaymentType PaymentType,
        Guid? CustomerId = null,
        decimal DiscountAmount = 0,
        decimal DownPayment = 0,        // مقدم الأقساط (يُدفع عند إنشاء الفاتورة)
        decimal VatRate = 0,            // نسبة الضريبة (0 = بدون ضريبة)
        InvoiceStatus Status = InvoiceStatus.Completed,
        string? Notes = null
    );

    // ── GET /api/invoices — List with filters ────────────────────────────────
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] Guid? customerId = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        [FromQuery] InvoiceStatus? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Invoices
            .Include(i => i.Customer)
            .AsQueryable();

        if (customerId.HasValue) query = query.Where(i => i.CustomerId == customerId);
        if (from.HasValue) query = query.Where(i => i.CreatedAt >= from.Value);
        if (to.HasValue) query = query.Where(i => i.CreatedAt <= to.Value);
        if (status.HasValue) query = query.Where(i => i.Status == status.Value);

        var total = await query.CountAsync(cancellationToken);
        var invoices = await query
            .OrderByDescending(i => i.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new
            {
                i.Id, i.InvoiceNo, i.CreatedAt, i.Status,
                i.TotalAmount, i.DiscountAmount, i.VatAmount, i.PaidAmount, i.RemainingAmount,
                PaymentType = i.PaymentType.ToString(),
                CustomerName = i.Customer != null ? i.Customer.Name : "عميل نقدي",
                ItemCount = i.Items.Count
            })
            .ToListAsync(cancellationToken);

        return Ok(new { total, page, pageSize, data = invoices });
    }

    // ── GET /api/invoices/{id} — Single invoice with items ──────────────────
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Items).ThenInclude(it => it.Product)
            .FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

        if (invoice == null) return NotFound();
        return Ok(invoice);
    }

    // ── POST /api/invoices — Create invoice ──────────────────────────────────
    [HttpPost]
    public async Task<IActionResult> CreateInvoice([FromBody] InvoiceCreateRequest request, CancellationToken cancellationToken)
    {
        if (request.ScannedItems == null || !request.ScannedItems.Any())
            return BadRequest(new { message = "يجب أن تحتوي الفاتورة على صنف واحد على الأقل." });

        // Extract cashier ID from JWT token
        var cashierIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var cashierId = cashierIdStr != null ? Guid.Parse(cashierIdStr) : (Guid?)null;

        var invoice = new Invoice
        {
            InvoiceNo = $"INV-{DateTime.UtcNow:yyyyMMddHHmmss}-{Random.Shared.Next(1000, 9999)}",
            PaymentType = request.PaymentType,
            Status = request.Status,
            CustomerId = request.CustomerId,
            CashierId = cashierId,
            DiscountAmount = request.DiscountAmount,
            VatRate = request.VatRate,
            Notes = request.Notes,
            CreatedBy = User.FindFirstValue(ClaimTypes.Name) ?? "System"
        };

        // ── Scanner Aggregation (group repeated scans of the same barcode) ──
        var groupedScans = request.ScannedItems
            .GroupBy(i => i.Barcode)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Quantity));

        foreach (var scan in groupedScans)
        {
            var barcode = scan.Key;
            var quantity = scan.Value;

            var product = await _productCacheService.GetProductByBarcodeAsync(barcode, cancellationToken);
            if (product == null)
                return BadRequest(new { message = $"لا يوجد منتج بهذا الباركود: {barcode}" });

            // Check bundle components
            var bundleComponents = await _dbContext.Bundles
                .Where(b => b.ParentProductId == product.Id)
                .ToListAsync(cancellationToken);

            if (bundleComponents.Any())
            {
                foreach (var bundleItem in bundleComponents)
                {
                    var subProduct = await _dbContext.Products.FindAsync(new object[] { bundleItem.SubProductId }, cancellationToken);
                    if (subProduct != null)
                    {
                        int totalSubQtyRequired = bundleItem.QuantityRequired * quantity;
                        if (subProduct.StockQuantity < totalSubQtyRequired)
                            return BadRequest(new { message = $"الكمية غير كافية للمنتج المكوّن: {subProduct.Name}. المتاح: {subProduct.StockQuantity}" });

                        subProduct.StockQuantity -= totalSubQtyRequired;
                        _dbContext.Products.Update(subProduct);
                        await _productCacheService.RemoveProductCacheAsync(subProduct.GlobalBarcode, cancellationToken);
                        if (!string.IsNullOrEmpty(subProduct.InternalBarcode))
                            await _productCacheService.RemoveProductCacheAsync(subProduct.InternalBarcode, cancellationToken);
                    }
                }
            }
            else
            {
                if (product.StockQuantity < quantity)
                    return BadRequest(new { message = $"الكمية غير كافية للمنتج: {product.Name}. المتاح: {product.StockQuantity}, المطلوب: {quantity}" });

                product.StockQuantity -= quantity;
                _dbContext.Products.Update(product);
            }

            await _productCacheService.SetProductCacheAsync(product, cancellationToken);

            invoice.Items.Add(new InvoiceItem
            {
                ProductId = product.Id,
                Quantity = quantity,
                UnitPrice = product.Price
            });
        }

        // ── Financial calculations ────────────────────────────────────────────
        var subTotal = invoice.Items.Sum(i => i.TotalPrice);

        // Auto-apply shop VAT if no explicit VatRate provided
        var effectiveVatRate = request.VatRate;
        if (effectiveVatRate == 0)
        {
            var shopSettings = await _dbContext.ShopSettings.FirstOrDefaultAsync(cancellationToken);
            if (shopSettings?.VatEnabled == true)
                effectiveVatRate = shopSettings.DefaultVatRate;
        }

        var vatAmount = Math.Round((subTotal - request.DiscountAmount) * (effectiveVatRate / 100m), 2);
        var totalAmount = subTotal - request.DiscountAmount + vatAmount;

        invoice.SubTotal = subTotal;
        invoice.VatRate = effectiveVatRate;
        invoice.VatAmount = vatAmount;
        invoice.TotalAmount = totalAmount;


        // Payment tracking for installments
        if (request.PaymentType == PaymentType.Installment)
        {
            invoice.PaidAmount = request.DownPayment;
            invoice.RemainingAmount = totalAmount - request.DownPayment;
        }
        else
        {
            invoice.PaidAmount = totalAmount;
            invoice.RemainingAmount = 0;
        }

        _dbContext.Invoices.Add(invoice);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            invoice.Id,
            invoice.InvoiceNo,
            invoice.SubTotal,
            invoice.DiscountAmount,
            invoice.VatAmount,
            invoice.TotalAmount,
            invoice.PaidAmount,
            invoice.RemainingAmount,
            ItemCount = invoice.Items.Count
        });
    }
}
