using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP;

[ApiController]
[Route("api/erp/bridal-orders")]
[Authorize]
public class BridalOrdersController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IAccountingService _accountingService;

    public BridalOrdersController(ApplicationDbContext dbContext, IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _accountingService = accountingService;
    }

    public record CreateBridalOrderRequest(
        Guid CustomerId,
        decimal TotalAmount,
        decimal DownPayment,
        DateTime? EventDate,
        DateTime? DeliveryDate,
        string? BridalNotes,
        List<BridalItemRequest>? Items
    );

    public record BridalItemRequest(
        Guid ProductId,
        int Quantity,
        decimal UnitPrice
    );

    // GET /api/erp/bridal-orders — List all bridal orders with customer info
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search = null,
        CancellationToken ct = default)
    {
        var query = _dbContext.Invoices
            .Where(i => i.IsBridal)
            .Include(i => i.Customer)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(i => i.Customer != null &&
                (i.Customer.Name.Contains(search) || (i.Customer.Phone != null && i.Customer.Phone.Contains(search))));

        var orders = await query
            .OrderByDescending(i => i.CreatedAt)
            .Select(i => new
            {
                i.Id,
                i.InvoiceNo,
                CustomerName = i.Customer != null ? i.Customer.Name : "",
                CustomerPhone = i.Customer != null ? i.Customer.Phone : null,
                CustomerId = i.CustomerId,
                i.TotalAmount,
                i.PaidAmount,
                i.RemainingAmount,
                i.EventDate,
                i.DeliveryDate,
                i.BridalNotes,
                i.Status,
                i.CreatedAt,
                ItemCount = i.Items.Count
            })
            .ToListAsync(ct);

        return Ok(orders);
    }

    // GET /api/erp/bridal-orders/{id} — Details of a single bridal order with items
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var order = await _dbContext.Invoices
            .Where(i => i.Id == id && i.IsBridal)
            .Include(i => i.Customer)
            .Select(i => new
            {
                i.Id,
                i.InvoiceNo,
                CustomerName = i.Customer != null ? i.Customer.Name : "",
                CustomerPhone = i.Customer != null ? i.Customer.Phone : null,
                CustomerId = i.CustomerId,
                i.TotalAmount,
                i.PaidAmount,
                i.RemainingAmount,
                i.EventDate,
                i.DeliveryDate,
                i.BridalNotes,
                Status = (int)i.Status,
                i.CreatedAt,
                Items = i.Items.Select(item => new
                {
                    item.Id,
                    item.ProductId,
                    ProductName = item.Product != null ? item.Product.Name : "",
                    StockQuantity = item.Product != null ? item.Product.StockQuantity : 0,
                    item.Quantity,
                    item.UnitPrice,
                    TotalPrice = item.Quantity * item.UnitPrice
                }).ToList()
            })
            .FirstOrDefaultAsync(ct);

        if (order == null) return NotFound();
        return Ok(order);
    }

    // GET /api/erp/bridal-orders/products-by-category?category=ثلاجة — Products filtered by category
    [HttpGet("products-by-category")]
    public async Task<IActionResult> GetProductsByCategory(
        [FromQuery] string category,
        CancellationToken ct)
    {
        var products = await _dbContext.Products
            .Where(p => p.IsActive && p.Category != null &&
                   EF.Functions.ILike(p.Category, $"%{category}%"))
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.Category,
                p.Price,
                p.StockQuantity,
                p.ImageUrl,
                IsAvailable = p.StockQuantity > 0
            })
            .OrderBy(p => p.Name)
            .ToListAsync(ct);

        return Ok(products);
    }

    // POST /api/erp/bridal-orders — Create new bridal order
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateBridalOrderRequest request)
    {
        var cashierIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var cashierId = cashierIdStr != null ? Guid.Parse(cashierIdStr) : (Guid?)null;
        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

        using var transaction = await _dbContext.Database.BeginTransactionAsync();
        try
        {
            var subTotal = request.Items?.Sum(i => i.Quantity * i.UnitPrice) ?? request.TotalAmount;

            var invoice = new Invoice
            {
                InvoiceNo = $"BRD-{DateTime.UtcNow:yyyyMMddHHmmss}",
                PaymentType = PaymentType.Installment,
                Status = InvoiceStatus.Reserved,
                CustomerId = request.CustomerId,
                CashierId = cashierId,
                SubTotal = subTotal,
                TotalAmount = subTotal,
                PaidAmount = request.DownPayment,
                RemainingAmount = subTotal - request.DownPayment,
                IsBridal = true,
                EventDate = request.EventDate,
                DeliveryDate = request.DeliveryDate,
                BridalNotes = request.BridalNotes,
                CreatedBy = createdBy
            };

            // Add items if provided
            if (request.Items != null && request.Items.Count > 0)
            {
                foreach (var item in request.Items)
                {
                    invoice.Items.Add(new InvoiceItem
                    {
                        ProductId = item.ProductId,
                        Quantity = item.Quantity,
                        UnitPrice = item.UnitPrice
                    });
                }
            }

            _dbContext.Invoices.Add(invoice);

            // Record down payment as installment
            if (request.DownPayment > 0)
            {
                var inst = new Installment
                {
                    InvoiceId = invoice.Id,
                    CustomerId = request.CustomerId,
                    Amount = request.DownPayment,
                    DueDate = DateTime.UtcNow,
                    Status = InstallmentStatus.Paid,
                    PaidAt = DateTime.UtcNow
                };
                _dbContext.Installments.Add(inst);

                // Record in accounting
                var dummyInvoice = new Invoice
                {
                    InvoiceNo = invoice.InvoiceNo,
                    PaidAmount = request.DownPayment,
                    PaymentType = PaymentType.Installment,
                    Items = new List<InvoiceItem>()
                };
                await _accountingService.RecordCashSaleAsync(dummyInvoice, createdBy);
            }

            // Record remaining as pending installment
            if (invoice.RemainingAmount > 0)
            {
                var remaining = new Installment
                {
                    InvoiceId = invoice.Id,
                    CustomerId = request.CustomerId,
                    Amount = invoice.RemainingAmount,
                    DueDate = request.EventDate ?? DateTime.UtcNow.AddDays(30),
                    Status = InstallmentStatus.Pending
                };
                _dbContext.Installments.Add(remaining);
            }

            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new { id = invoice.Id, invoiceNo = invoice.InvoiceNo });
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            return BadRequest(new { message = ex.Message });
        }
    }

    // PATCH /api/erp/bridal-orders/{id}/items — Update checklist items for an order
    [HttpPatch("{id:guid}/items")]
    public async Task<IActionResult> UpdateItems(Guid id, [FromBody] List<BridalItemRequest> items, CancellationToken ct)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == id && i.IsBridal, ct);

        if (invoice == null) return NotFound();

        // Remove old items
        _dbContext.InvoiceItems.RemoveRange(invoice.Items);

        // Add new items
        var newSubTotal = 0m;
        foreach (var item in items)
        {
            var ii = new InvoiceItem
            {
                InvoiceId = invoice.Id,
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice
            };
            _dbContext.InvoiceItems.Add(ii);
            newSubTotal += item.Quantity * item.UnitPrice;
        }

        // Update totals
        invoice.SubTotal = newSubTotal;
        invoice.TotalAmount = newSubTotal;
        invoice.RemainingAmount = newSubTotal - invoice.PaidAmount;

        await _dbContext.SaveChangesAsync(ct);
        return Ok(new { message = "تم تحديث قائمة الأجهزة", newTotal = newSubTotal });
    }

    // GET /api/erp/bridal-orders/reminders — Get approaching bridal deliveries and identify missing stock
    [HttpGet("reminders")]
    public async Task<IActionResult> GetReminders(CancellationToken ct)
    {
        var upcoming = DateTime.UtcNow.AddDays(14); // Next 14 days
        var orders = await _dbContext.Invoices
            .Where(i => i.IsBridal && i.Status == InvoiceStatus.Reserved && i.DeliveryDate != null && i.DeliveryDate <= upcoming)
            .Include(i => i.Customer)
            .Include(i => i.Items)
            .ThenInclude(ii => ii.Product)
            .OrderBy(i => i.DeliveryDate)
            .ToListAsync(ct);

        var result = new List<object>();

        foreach (var invoice in orders)
        {
            var missingItems = new List<object>();
            bool canDeliver = true;

            foreach (var item in invoice.Items)
            {
                if (item.Product != null && item.Product.StockQuantity < item.Quantity)
                {
                    canDeliver = false;
                    missingItems.Add(new
                    {
                        item.Product.Id,
                        item.Product.Name,
                        RequiredQuantity = item.Quantity,
                        AvailableQuantity = item.Product.StockQuantity,
                        MissingQuantity = item.Quantity - item.Product.StockQuantity
                    });
                }
            }

            result.Add(new
            {
                invoice.Id,
                invoice.InvoiceNo,
                CustomerName = invoice.Customer?.Name ?? "غير محدد",
                CustomerPhone = invoice.Customer?.Phone,
                invoice.DeliveryDate,
                DaysRemaining = Math.Max(0, (invoice.DeliveryDate.Value.Date - DateTime.UtcNow.Date).Days),
                MissingItems = missingItems,
                CanDeliver = canDeliver
            });
        }

        return Ok(result);
    }

    // POST /api/erp/bridal-orders/{id}/deliver — Marks a reserved bridal order as completed and deducts stock
    [HttpPost("{id:guid}/deliver")]
    public async Task<IActionResult> DeliverOrder(Guid id, CancellationToken ct)
    {
        var invoice = await _dbContext.Invoices
            .Include(i => i.Items)
            .ThenInclude(ii => ii.Product)
            .FirstOrDefaultAsync(i => i.Id == id && i.IsBridal, ct);

        if (invoice == null) return NotFound("الطلب غير موجود.");
        if (invoice.Status == InvoiceStatus.Completed) return BadRequest("هذا الطلب تم تسليمه مسبقاً.");

        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

        using var transaction = await _dbContext.Database.BeginTransactionAsync(ct);
        try
        {
            // First check if all items have enough stock
            var missing = new List<string>();
            foreach (var item in invoice.Items)
            {
                if (item.Product == null || item.Product.StockQuantity < item.Quantity)
                {
                    missing.Add($"{item.Product?.Name ?? "منتج غير معروف"} (مطلوب: {item.Quantity}, متوفر: {item.Product?.StockQuantity ?? 0})");
                }
            }

            if (missing.Any())
            {
                return BadRequest(new { message = "عذراً، الرصيد الحالي لا يكفي لتسليم الأجهزة التالية:", missing });
            }

            // Deduct stock and log movements
            foreach (var item in invoice.Items)
            {
                if (item.Product != null)
                {
                    item.Product.StockQuantity -= item.Quantity;
                    _dbContext.Products.Update(item.Product);

                    _dbContext.StockMovements.Add(new StockMovement
                    {
                        ProductId = item.Product.Id,
                        Type = StockMovementType.Sale,
                        Quantity = -(int)item.Quantity,
                        BalanceAfter = (int)item.Product.StockQuantity,
                        ReferenceId = invoice.Id,
                        ReferenceNumber = invoice.InvoiceNo,
                        CreatedBy = createdBy,
                        Notes = "استلام طلب عروسة"
                    });
                }
            }

            invoice.Status = InvoiceStatus.Completed;
            await _dbContext.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);

            return Ok(new { message = "تم تسليم الطلب وخصم البضاعة من المخزون بنجاح." });
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(ct);
            return BadRequest(new { message = "حدث خطأ أثناء إجراء التسليم.", details = ex.Message });
        }
    }
}
