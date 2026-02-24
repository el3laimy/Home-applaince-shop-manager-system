using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public ReportsController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpGet("bridal-statement/{customerId:guid}")]
    public async Task<IActionResult> GetBridalStatement(Guid customerId, CancellationToken cancellationToken)
    {
        // 1. Get all invoices for the customer
        var invoices = await _dbContext.Invoices
            .Include(i => i.Items)
            .ThenInclude(i => i.Product)
            .Where(i => i.CustomerId == customerId && i.PaymentType == PaymentType.Installment)
            .ToListAsync(cancellationToken);

        if (!invoices.Any())
            return NotFound("No bridal/installment records found for this customer.");

        // 2. Get all installments
        var invoiceIds = invoices.Select(i => i.Id).ToList();
        var installments = await _dbContext.Installments
            .Where(i => invoiceIds.Contains(i.InvoiceId))
            .ToListAsync(cancellationToken);

        // 3. Calculate Financials
        decimal totalPurchases = invoices.Sum(i => i.TotalAmount);
        decimal totalPaid = installments.Where(i => i.Status == InstallmentStatus.Paid).Sum(i => i.Amount);
        
        // Downpayment was paid at the time of invoice creation (TotalAmount - Sum of all installments)
        decimal totalInstallmentsExpected = installments.Sum(i => i.Amount);
        decimal downPaymentTotal = totalPurchases - totalInstallmentsExpected;
        
        totalPaid += downPaymentTotal;
        decimal remainingBalance = totalPurchases - totalPaid;

        // 4. Identify Undelivered goods (Reserved Invoices)
        var reservedItems = invoices
            .Where(i => i.Status == InvoiceStatus.Reserved)
            .SelectMany(i => i.Items)
            .GroupBy(i => new { i.ProductId, i.Product!.Name })
            .Select(g => new
            {
                g.Key.ProductId,
                ProductName = g.Key.Name,
                QuantityOrderedButNotReceived = g.Sum(i => i.Quantity)
            })
            .ToList();

        return Ok(new
        {
            CustomerId = customerId,
            Financials = new
            {
                TotalPurchases = totalPurchases,
                TotalPaid = totalPaid,
                RemainingBalance = remainingBalance,
                DownPaymentsIncluded = downPaymentTotal
            },
            PendingInstallments = installments.Where(i => i.Status == InstallmentStatus.Pending).OrderBy(i => i.DueDate).Select(i => new
            {
                i.Id,
                i.Amount,
                i.DueDate,
                IsOverdue = i.DueDate < DateTime.UtcNow
            }),
            UnreceivedGoods = reservedItems
        });
    }

    [HttpGet("sales")]
    public async Task<IActionResult> GetSalesReport([FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate, CancellationToken cancellationToken)
    {
        var start = startDate ?? DateTime.UtcNow.Date.AddDays(-30); // Default last 30 days
        var end = endDate ?? DateTime.UtcNow;

        var sales = await _dbContext.Invoices
            .Include(i => i.Items)
            .ThenInclude(i => i.Product)
            .Where(i => i.CreatedAt >= start && i.CreatedAt <= end && i.Status == InvoiceStatus.Completed)
            .ToListAsync(cancellationToken);

        var returns = await _dbContext.ReturnInvoices
            .Include(r => r.Items)
            .Where(r => r.CreatedAt >= start && r.CreatedAt <= end)
            .ToListAsync(cancellationToken);

        // Calculate Revenue and Cost
        decimal totalRevenue = sales.Sum(i => i.TotalAmount) - sales.Sum(i => i.DiscountAmount);
        decimal totalCost = sales.SelectMany(i => i.Items).Sum(item => item.Quantity * (item.Product?.PurchasePrice ?? 0));
        
        // Subtract Returns
        decimal totalRefunds = returns.Sum(r => r.RefundAmount);
        
        decimal netRevenue = totalRevenue - totalRefunds;
        decimal netProfit = netRevenue - totalCost;

        // Group by Day for chart
        var salesByDay = sales
            .GroupBy(i => i.CreatedAt.Date)
            .Select(g => new
            {
                Date = g.Key.ToString("yyyy-MM-dd"),
                Revenue = g.Sum(x => x.TotalAmount - x.DiscountAmount)
            })
            .OrderBy(x => x.Date)
            .ToList();

        return Ok(new
        {
            Period = new { Start = start, End = end },
            Metrics = new
            {
                TotalRevenue = totalRevenue,
                TotalCost = totalCost,
                TotalRefunds = totalRefunds,
                NetRevenue = netRevenue,
                NetProfit = netProfit,
                InvoiceCount = sales.Count
            },
            SalesTrend = salesByDay
        });
    }

    [HttpGet("inventory-value")]
    public async Task<IActionResult> GetInventoryValue(CancellationToken cancellationToken)
    {
        var products = await _dbContext.Products
            .Where(p => p.StockQuantity > 0)
            .Select(p => new
            {
                p.Category,
                Value = p.StockQuantity * p.PurchasePrice,
                RetailValue = p.StockQuantity * p.Price
            })
            .ToListAsync(cancellationToken);

        var totalCostValue = products.Sum(p => p.Value);
        var totalRetailValue = products.Sum(p => p.RetailValue);
        var expectedProfit = totalRetailValue - totalCostValue;

        var byCategory = products
            .GroupBy(p => p.Category ?? "غير مصنف")
            .Select(g => new
            {
                Category = g.Key,
                Value = g.Sum(p => p.Value)
            })
            .OrderByDescending(x => x.Value)
            .ToList();

        return Ok(new
        {
            TotalCostValue = totalCostValue,
            TotalRetailValue = totalRetailValue,
            ExpectedProfit = expectedProfit,
            ValueByCategory = byCategory
        });
    }

    [HttpGet("top-products")]
    public async Task<IActionResult> GetTopProducts([FromQuery] int limit = 10, CancellationToken cancellationToken = default)
    {
        var topProducts = await _dbContext.InvoiceItems
            .Include(i => i.Invoice)
            .Include(i => i.Product)
            .Where(i => i.Invoice!.Status == InvoiceStatus.Completed)
            .GroupBy(i => new { i.ProductId, i.Product!.Name })
            .Select(g => new
            {
                ProductId = g.Key.ProductId,
                ProductName = g.Key.Name,
                QuantitySold = g.Sum(x => x.Quantity),
                TotalRevenue = g.Sum(x => x.Quantity * x.UnitPrice)
            })
            .OrderByDescending(x => x.QuantitySold)
            .Take(limit)
            .ToListAsync(cancellationToken);

        return Ok(topProducts);
    }
}
