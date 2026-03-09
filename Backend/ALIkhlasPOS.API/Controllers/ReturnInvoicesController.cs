using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class ReturnInvoicesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IAccountingService _accountingService;

    public ReturnInvoicesController(ApplicationDbContext dbContext, IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _accountingService = accountingService;
    }

    public record ReturnItemRequest(Guid ProductId, decimal Quantity, Guid? ParentBundleId = null, decimal? CustomUnitPrice = null);
    public record CreateReturnRequest(Guid OriginalInvoiceId, ReturnReason Reason, string? Notes, List<ReturnItemRequest> Items);

    // GET /api/returninvoices
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? search, CancellationToken cancellationToken)
    {
        var query = _dbContext.ReturnInvoices
            .Include(r => r.OriginalInvoice)
                .ThenInclude(oi => oi.Customer)
            .Include(r => r.Items)
                .ThenInclude(i => i.Product)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.ToLower();
            query = query.Where(r => 
                r.ReturnNo.ToLower().Contains(s) || 
                r.OriginalInvoice.InvoiceNo.ToLower().Contains(s) ||
                (r.OriginalInvoice.Customer != null && r.OriginalInvoice.Customer.Name.ToLower().Contains(s))
            );
        }

        var returns = await query
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.Id,
                r.ReturnNo,
                r.OriginalInvoiceId,
                OriginalInvoiceNo = r.OriginalInvoice.InvoiceNo,
                CustomerName = r.OriginalInvoice.Customer != null ? r.OriginalInvoice.Customer.Name : "عميل نقدي",
                r.Reason,
                r.Notes,
                r.RefundAmount,
                r.CreatedBy,
                r.CreatedAt,
                Items = r.Items.Select(i => new {
                    i.ProductId,
                    ProductName = i.Product.Name,
                    i.Quantity,
                    i.UnitPrice,
                    i.TotalPrice
                })
            })
            .ToListAsync(cancellationToken);

        return Ok(returns);
    }

    // POST /api/returninvoices — Process a product return
    [HttpPost]
    public async Task<IActionResult> ProcessReturn([FromBody] CreateReturnRequest request, CancellationToken cancellationToken)
    {
        var originalInvoice = await _dbContext.Invoices
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == request.OriginalInvoiceId, cancellationToken);

        if (originalInvoice == null)
            return BadRequest(new { message = "الفاتورة الأصلية غير موجودة." });

        var returnInvoice = new ReturnInvoice
        {
            ReturnNo = $"RET-{DateTime.UtcNow:yyyyMMddHHmmss}",
            OriginalInvoiceId = request.OriginalInvoiceId,
            Reason = request.Reason,
            Notes = request.Notes,
            // BUG-03: Use authenticated user instead of hardcoded "SystemUser"
            CreatedBy = User.FindFirstValue(ClaimTypes.Name) ?? "System"
        };

        var previouslyReturnedItems = await _dbContext.ReturnInvoices
            .Where(r => r.OriginalInvoiceId == request.OriginalInvoiceId)
            .SelectMany(r => r.Items)
            .ToListAsync(cancellationToken);
            
        var returnedQtyByProduct = previouslyReturnedItems
            .GroupBy(ri => ri.ProductId)
            .ToDictionary(g => g.Key, g => g.Sum(ri => ri.Quantity));

        foreach (var item in request.Items)
        {
            var invoiceProductId = item.ParentBundleId ?? item.ProductId;
            var originalItem = originalInvoice.Items.FirstOrDefault(i => i.ProductId == invoiceProductId);
            if (originalItem == null)
            {
                return BadRequest(new { message = $"المنتج الأساسي/العرض لم يتم بيعه في الفاتورة الأصلية." });
            }

            decimal previouslyReturned = returnedQtyByProduct.GetValueOrDefault(item.ProductId, 0);
            decimal maxReturnable = originalItem.Quantity;

            // If it's a bundle part, calculate max based on bundle configuration
            if (item.ParentBundleId.HasValue)
            {
                var bundleComp = await _dbContext.Bundles.FirstOrDefaultAsync(b => b.ParentProductId == item.ParentBundleId.Value && b.SubProductId == item.ProductId, cancellationToken);
                if (bundleComp == null)
                    return BadRequest(new { message = "هذا المنتج ليس جزءاً من العرض المحدد." });
                maxReturnable = originalItem.Quantity * bundleComp.QuantityRequired;
            }

            maxReturnable -= previouslyReturned;

            if (item.Quantity > maxReturnable)
            {
                var productFailed = await _dbContext.Products.FindAsync(new object[] { item.ProductId }, cancellationToken);
                return BadRequest(new { message = $"الكمية المرتجعة للمنتج ({(productFailed?.Name ?? "غير معروف")}) تتجاوز المسموح به ({maxReturnable})." });
            }

            var product = await _dbContext.Products.FindAsync(new object[] { item.ProductId }, cancellationToken);
            if (product != null)
            {
                // Restore stock
                product.StockQuantity += (int)item.Quantity;
                _dbContext.Products.Update(product);

                // Log stock movement
                _dbContext.StockMovements.Add(new StockMovement
                {
                    ProductId = product.Id,
                    Type = StockMovementType.ReturnSale,
                    Quantity = (int)item.Quantity, // Positive because it's coming back
                    BalanceAfter = (int)product.StockQuantity,
                    ReferenceId = returnInvoice.Id, // Note: returnInvoice.Id is generated here (Guid.NewGuid() default initially)
                    ReferenceNumber = returnInvoice.ReturnNo,
                    CreatedBy = returnInvoice.CreatedBy,
                    Notes = item.ParentBundleId.HasValue ? "إرجاع جزء من عرض" : null
                });
            }

            decimal unitPriceToRefund = item.CustomUnitPrice ?? (item.ParentBundleId.HasValue ? (product?.Price ?? 0) : originalItem.UnitPrice);

            returnInvoice.Items.Add(new ReturnInvoiceItem
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = unitPriceToRefund
            });
        }

        returnInvoice.RefundAmount = returnInvoice.Items.Sum(i => i.TotalPrice);
        
        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            _dbContext.ReturnInvoices.Add(returnInvoice);
            await _dbContext.SaveChangesAsync(cancellationToken);
            
            // BUG-03: Record return in treasury & accounting
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
            await _accountingService.RecordSalesReturnAsync(returnInvoice, createdBy);

            // FIX-G: Update Customer balance and Invoice amounts
            if (originalInvoice.CustomerId.HasValue)
            {
                var customer = await _dbContext.Customers.FindAsync(
                    new object[] { originalInvoice.CustomerId.Value }, cancellationToken);
                if (customer != null)
                {
                    customer.TotalPurchases -= returnInvoice.RefundAmount;
                    customer.TotalPaid -= returnInvoice.RefundAmount;
                }
            }

            // Reduce Invoice paid amount (money refunded to customer)
            originalInvoice.PaidAmount = Math.Max(0, originalInvoice.PaidAmount - returnInvoice.RefundAmount);
            originalInvoice.RemainingAmount = Math.Max(0, originalInvoice.TotalAmount - originalInvoice.PaidAmount);

            await _dbContext.SaveChangesAsync(cancellationToken);
            
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return BadRequest(new { message = $"حدث خطأ أثناء حفظ المرتجع: {ex.Message}" });
        }

        return Ok(new
        {
            returnInvoice.Id,
            returnInvoice.ReturnNo,
            returnInvoice.RefundAmount,
            Message = "تم تسجيل المرتجع وإعادة الكميات للمخزن بنجاح."
        });
    }
}
