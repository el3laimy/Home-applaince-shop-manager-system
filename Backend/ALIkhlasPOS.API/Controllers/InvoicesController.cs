using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
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
    private readonly IAccountingService _accountingService;
    private readonly ALIkhlasPOS.Application.Services.InvoicePdfGenerator _pdfGenerator;

    public InvoicesController(
        ApplicationDbContext dbContext, 
        IProductCacheService productCacheService, 
        IAccountingService accountingService,
        ALIkhlasPOS.Application.Services.InvoicePdfGenerator pdfGenerator,
        IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> hubContext)
    {
        _dbContext = dbContext;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
        _pdfGenerator = pdfGenerator;
        _hubContext = hubContext;
    }

    // ── Request DTOs ─────────────────────────────────────────────────────────
    public record ScanItemRequest(string Barcode, int Quantity = 1, decimal? CustomPrice = null);

    public record InvoiceCreateRequest(
        List<ScanItemRequest> ScannedItems,
        PaymentType PaymentType,
        Guid? CustomerId = null,
        decimal DiscountAmount = 0,
        decimal DownPayment = 0,        // مقدم الأقساط (يُدفع عند إنشاء الفاتورة)
        decimal VatRate = 0,            // نسبة الضريبة (0 = بدون ضريبة)
        decimal InterestRate = 0,       // نسبة الفائدة % على المتبقي (للتقسيط)
        InstallmentPeriod InstallmentPeriod = InstallmentPeriod.Monthly, // نوع القسط
        int InstallmentCount = 0,       // عدد الأقساط
        InvoiceStatus Status = InvoiceStatus.Completed,
        string? Notes = null,
        bool IsBridal = false,
        DateTime? EventDate = null,
        DateTime? DeliveryDate = null,
        string? BridalNotes = null,
        string? PaymentReference = null, // رقم العملية لـ Visa/BankTransfer
        decimal SplitCashAmount = 0,    // مبلغ الدفع المقسم (نقدًا)
        decimal SplitVisaAmount = 0     // مبلغ الدفع المقسم (فيزا)
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

    // ── GET /api/invoices/{id}/pdf — Generate PDF receipt ───────────────────
    [HttpGet("{id:guid}/pdf")]
    [AllowAnonymous] // Might want to secure this depending on architecture, but usually receipts are safe if ID is UUID
    public async Task<IActionResult> DownloadPdf(Guid id, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Items).ThenInclude(it => it.Product)
            .FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

        if (invoice == null) return NotFound(new { message = "الفاتورة غير موجودة" });

        try
        {
            var pdfBytes = _pdfGenerator.GenerateInvoicePdf(invoice);
            return File(pdfBytes, "application/pdf", $"Invoice_{invoice.InvoiceNo}.pdf");
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"خطأ أثناء توليد الـ PDF: {ex.Message}" });
        }
    }

    // ── GET /api/invoices/by-no/{invoiceNo} — Used by Returns Screen ──────────
    [HttpGet("by-no/{invoiceNo}")]
    public async Task<IActionResult> GetByInvoiceNo(string invoiceNo, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Items).ThenInclude(it => it.Product)
            .FirstOrDefaultAsync(i => i.InvoiceNo.ToLower() == invoiceNo.ToLower(), cancellationToken);

        if (invoice == null) return NotFound(new { message = "رقم الفاتورة غير موجود." });

        if (invoice.Status == InvoiceStatus.Reserved)
            return BadRequest(new { message = "لا يمكن إرجاع فاتورة غير مكتملة الدفع أو قيد الحجز." });

        // Calculate how many of each item were already returned
        var previouslyReturnedItems = await _dbContext.ReturnInvoices
            .Where(r => r.OriginalInvoiceId == invoice.Id)
            .SelectMany(r => r.Items)
            .ToListAsync(cancellationToken);
            
        var returnedQtyByProduct = previouslyReturnedItems
            .GroupBy(ri => ri.ProductId)
            .ToDictionary(g => g.Key, g => g.Sum(ri => ri.Quantity));

        var allProductIds = invoice.Items.Select(i => i.ProductId).ToList();
        var allBundles = await _dbContext.Bundles
            .Include(b => b.SubProduct)
            .Where(b => allProductIds.Contains(b.ParentProductId))
            .ToListAsync(cancellationToken);

        var response = new
        {
            invoice.Id,
            invoice.InvoiceNo,
            invoice.CreatedAt,
            invoice.TotalAmount,
            invoice.PaidAmount,
            invoice.RemainingAmount,
            CustomerName = invoice.Customer != null ? invoice.Customer.Name : "عميل نقدي",
            Items = invoice.Items.Select(i => {
                var isBundle = allBundles.Any(b => b.ParentProductId == i.ProductId);
                var bundleItems = allBundles.Where(b => b.ParentProductId == i.ProductId).Select(b => new {
                    SubProductId = b.SubProductId,
                    SubProductName = b.SubProduct?.Name ?? "غير معروف",
                    QuantityRequired = b.QuantityRequired,
                    TotalSubQuantity = b.QuantityRequired * i.Quantity,
                    PreviouslyReturned = returnedQtyByProduct.GetValueOrDefault(b.SubProductId, 0),
                    // If returning a single sub-item, we need a baseline price. We'll send the sub-product's retail price as a suggestion
                    SuggestedRefundPrice = b.SubProduct?.Price ?? 0
                }).ToList();

                var mainReturnedQty = returnedQtyByProduct.GetValueOrDefault(i.ProductId, 0);

                return new
                {
                    i.ProductId,
                    i.Product.Name,
                    OriginalQuantity = i.Quantity,
                    ReturnedQuantity = mainReturnedQty,
                    ReturnableQuantity = i.Quantity - mainReturnedQty,
                    i.UnitPrice,
                    i.TotalPrice,
                    IsBundle = isBundle,
                    BundleItems = bundleItems
                };
            }).Where(i => i.ReturnableQuantity > 0 || (i.IsBundle && i.BundleItems.Any(b => b.TotalSubQuantity > b.PreviouslyReturned))).ToList()
        };

        if (!response.Items.Any())
            return BadRequest(new { message = "تم إرجاع جميع أصناف هذه الفاتورة مسبقاً." });

        return Ok(response);
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

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {

            // BUG-14: Sequential invoice number — safe under high load
            var today = DateTime.UtcNow.ToString("yyyyMMdd");
            var lastNo = await _dbContext.Invoices
                .Where(i => i.InvoiceNo.StartsWith($"INV-{today}-"))
                .OrderByDescending(i => i.InvoiceNo)
                .Select(i => i.InvoiceNo)
                .FirstOrDefaultAsync(cancellationToken);

            int seq = 1;
            if (lastNo != null)
            {
                var parts = lastNo.Split('-');
                if (parts.Length == 3 && int.TryParse(parts[2], out var lastSeq))
                    seq = lastSeq + 1;
            }

        var invoice = new Invoice
        {
            InvoiceNo = $"INV-{today}-{seq:D5}",
            PaymentType = request.PaymentType,
            Status = request.Status,
            CustomerId = request.CustomerId,
            CashierId = cashierId,
            DiscountAmount = request.DiscountAmount,
            VatRate = request.VatRate,
            Notes = request.Notes,
            IsBridal = request.IsBridal,
            EventDate = request.EventDate,
            DeliveryDate = request.DeliveryDate,
            BridalNotes = request.BridalNotes,
            InterestRate = request.InterestRate,
            InstallmentPeriod = request.InstallmentPeriod,
            InstallmentCount = request.InstallmentCount,
            CreatedBy = User.FindFirstValue(ClaimTypes.Name) ?? "System",
            PaymentReference = request.PaymentReference
        };

        // ── Scanner Aggregation (group repeated scans of the same barcode & price) ──
        var groupedScans = request.ScannedItems
            .GroupBy(i => new { i.Barcode, i.CustomPrice })
            .Select(g => new { g.Key.Barcode, g.Key.CustomPrice, Quantity = g.Sum(x => x.Quantity) })
            .ToList();

        foreach (var scan in groupedScans)
        {
            var barcode = scan.Barcode;
            var quantity = scan.Quantity;
            var customPrice = scan.CustomPrice;

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
                        
                        _dbContext.StockMovements.Add(new StockMovement
                        {
                            ProductId = subProduct.Id,
                            Type = StockMovementType.Sale,
                            Quantity = -(int)totalSubQtyRequired,
                            BalanceAfter = (int)subProduct.StockQuantity,
                            ReferenceId = invoice.Id,
                            ReferenceNumber = invoice.InvoiceNo,
                            CreatedBy = invoice.CreatedBy,
                            Notes = $"مرتبط بالمنتج المجمّع {product.Name}"
                        });
                        
                        if (!string.IsNullOrEmpty(subProduct.GlobalBarcode))
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

                _dbContext.StockMovements.Add(new StockMovement
                {
                    ProductId = product.Id,
                    Type = StockMovementType.Sale,
                    Quantity = -(int)quantity,
                    BalanceAfter = (int)product.StockQuantity,
                    ReferenceId = invoice.Id,
                    ReferenceNumber = invoice.InvoiceNo,
                    CreatedBy = invoice.CreatedBy
                });
            }

            await _productCacheService.SetProductCacheAsync(product, cancellationToken);

            // Verify Custom Price is not below Purchase Price (if applicable)
            decimal finalPrice = product.Price;
            if (customPrice.HasValue)
            {
                if (customPrice.Value < product.PurchasePrice)
                {
                    // Allow admin to override, but for now we reject if below cost
                    var role = User.FindFirstValue(ClaimTypes.Role);
                    if (role != "Admin")
                    {
                        return BadRequest(new { message = $"لا يمكن بيع المنتج {product.Name} بسعر أقل من التكلفة ({product.PurchasePrice})." });
                    }
                }
                finalPrice = customPrice.Value;
            }

            invoice.Items.Add(new InvoiceItem
            {
                ProductId = product.Id,
                Quantity = quantity,
                UnitPrice = finalPrice
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
            // Apply interest on the remaining amount
            var remaining = totalAmount - request.DownPayment;
            var interest = remaining * (request.InterestRate / 100m);
            var totalWithInterest = remaining + interest;
            invoice.RemainingAmount = totalWithInterest;
            invoice.TotalAmount = totalAmount + interest; // updated to include interest
        }
        else
        {
            invoice.PaidAmount = totalAmount;
            invoice.RemainingAmount = 0;
        }

        // ── Recording to Treasury & Accounting ──
        // FIX-D: Update Customer balance fields
        if (invoice.CustomerId.HasValue)
        {
            var customer = await _dbContext.Customers.FindAsync(new object[] { invoice.CustomerId.Value }, cancellationToken);
            if (customer != null)
            {
                customer.TotalPurchases += invoice.TotalAmount;
                customer.TotalPaid += invoice.PaidAmount;
            }
        }

        _dbContext.Invoices.Add(invoice);
        await _dbContext.SaveChangesAsync(cancellationToken);

        await _accountingService.RecordCashSaleAsync(invoice, invoice.CreatedBy, request.SplitCashAmount, request.SplitVisaAmount);
        
        await transaction.CommitAsync(cancellationToken);

        // Trigger SignalR broadcast for live dashboard update
        await _hubContext.Clients.All.SendAsync("UpdateDashboard", cancellationToken);

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
    catch (Exception ex)
    {
        await transaction.RollbackAsync(cancellationToken);
        return BadRequest(new { message = $"حدث خطأ أثناء حفظ الفاتورة أو المعاملة المالية: {ex.Message}" });
    }
    }
}
