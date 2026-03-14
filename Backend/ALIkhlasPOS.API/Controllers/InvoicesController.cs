using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InvoicesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IInvoiceService _invoiceService;
    private readonly IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> _hubContext;

    public InvoicesController(
        ApplicationDbContext dbContext, 
        IInvoiceService invoiceService,
        IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> hubContext)
    {
        _dbContext = dbContext;
        _invoiceService = invoiceService;
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

        // Map to anonymous DTO to prevent JSON circular reference errors
        var result = new
        {
            invoice.Id,
            invoice.InvoiceNo,
            invoice.CreatedAt,
            invoice.Status,
            invoice.PaymentType,
            invoice.TotalAmount,
            invoice.DiscountAmount,
            invoice.VatAmount,
            invoice.PaidAmount,
            invoice.RemainingAmount,
            invoice.Notes,
            Customer = invoice.Customer != null ? new { invoice.Customer.Id, invoice.Customer.Name, invoice.Customer.Phone } : null,
            Items = invoice.Items.Select(item => new
            {
                item.Id,
                item.ProductId,
                ProductName = item.Product != null ? item.Product.Name : "غير معروف",
                item.Quantity,
                item.UnitPrice,
                item.TotalPrice
            }).ToList()
        };

        return Ok(result);
    }

    // ── GET /api/invoices/{id}/pdf — Generate PDF receipt ───────────────────
    [HttpGet("{id:guid}/pdf")]
    public async Task<IActionResult> GetInvoicePdf(Guid id, [FromServices] ALIkhlasPOS.Application.Services.InvoicePdfGenerator pdfGenerator, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Items).ThenInclude(it => it.Product)
            .FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

        if (invoice == null) return NotFound(new { message = "الفاتورة غير موجودة" });

        try
        {
            var pdfBytes = pdfGenerator.GenerateInvoicePdf(invoice);
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

        var cashierIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var cashierId = cashierIdStr != null ? Guid.Parse(cashierIdStr) : (Guid?)null;
        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
        var isAdmin = User.FindFirstValue(ClaimTypes.Role) == "Admin";

        try
        {
            var dto = new ALIkhlasPOS.Application.DTOs.Invoices.InvoiceCreateDto(
                request.ScannedItems.Select(s => new ALIkhlasPOS.Application.DTOs.Invoices.ScanItemDto(s.Barcode, s.Quantity, s.CustomPrice)).ToList(),
                request.PaymentType,
                request.CustomerId,
                request.DiscountAmount,
                request.DownPayment,
                request.VatRate,
                request.InterestRate,
                request.InstallmentPeriod,
                request.InstallmentCount,
                request.Status,
                request.Notes,
                request.IsBridal,
                request.EventDate,
                request.DeliveryDate,
                request.BridalNotes,
                request.PaymentReference,
                request.SplitCashAmount,
                request.SplitVisaAmount
            );

            var response = await _invoiceService.CreateInvoiceAsync(dto, cashierId, createdBy, isAdmin, cancellationToken);
            
            // Trigger SignalR broadcast for live dashboard update
            await _hubContext.Clients.All.SendAsync("UpdateDashboard", cancellationToken);

            // Exact same return shape as before
            return Ok(new
            {
                Id = response.Id,
                InvoiceNo = response.InvoiceNo,
                SubTotal = response.SubTotal,
                DiscountAmount = response.DiscountAmount,
                VatAmount = response.VatAmount,
                TotalAmount = response.TotalAmount,
                PaidAmount = response.PaidAmount,
                RemainingAmount = response.RemainingAmount,
                ItemCount = response.ItemCount
            });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = $"حدث خطأ أثناء حفظ الفاتورة أو المعاملة المالية: {ex.Message}" });
        }
    }
}
