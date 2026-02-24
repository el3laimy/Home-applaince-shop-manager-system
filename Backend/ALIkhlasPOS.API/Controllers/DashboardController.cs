using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.API.Controllers
{
    [ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
    [Route("api/[controller]")]
    public class DashboardController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;

        public DashboardController(ApplicationDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        [HttpGet("summary")]
        public async Task<IActionResult> GetSummary(CancellationToken cancellationToken)
        {
            var today = DateTime.UtcNow.Date;
            var startOfMonth = new DateTime(today.Year, today.Month, 1, 0, 0, 0, DateTimeKind.Utc);

            // 1. Sales Data
            var todaySales = await _dbContext.Invoices
                .Where(i => i.CreatedAt >= today && i.Status == InvoiceStatus.Completed)
                .SumAsync(i => i.TotalAmount, cancellationToken);
                
            var dailyInvoicesCount = await _dbContext.Invoices
                .Where(i => i.CreatedAt >= today && i.Status == InvoiceStatus.Completed)
                .CountAsync(cancellationToken);

            var monthlySales = await _dbContext.Invoices
                .Where(i => i.CreatedAt >= startOfMonth && i.Status == InvoiceStatus.Completed)
                .SumAsync(i => i.TotalAmount, cancellationToken);

            // 2. Products Data
            var totalProducts = await _dbContext.Products.CountAsync(cancellationToken);
            
            var lowStockProducts = await _dbContext.Products
                .Where(p => p.StockQuantity <= p.MinStockAlert)
                .CountAsync(cancellationToken);

            // 3. Customers Data
            var totalCustomers = await _dbContext.Customers.CountAsync(cancellationToken);

            // 4. Recent Invoices
            var recentInvoices = await _dbContext.Invoices
                .Include(i => i.Customer)
                .Where(i => i.Status == InvoiceStatus.Completed)
                .OrderByDescending(i => i.CreatedAt)
                .Take(5)
                .Select(i => new
                {
                    i.Id,
                    i.InvoiceNo,
                    CustomerName = i.Customer != null ? i.Customer.Name : "عميل نقدي",
                    i.TotalAmount,
                    i.CreatedAt,
                    PaymentType = i.PaymentType.ToString()
                })
                .ToListAsync(cancellationToken);

            // 5. Sales & Profit Trend (Last 7 Days)
            var weekAgo = today.AddDays(-6);
            
            var salesDataRaw = await _dbContext.Invoices
                .Where(i => i.CreatedAt >= weekAgo && i.Status == InvoiceStatus.Completed)
                .GroupBy(i => i.CreatedAt.Date)
                .Select(g => new { Date = g.Key, Total = g.Sum(i => i.TotalAmount) })
                .ToListAsync(cancellationToken);

            // Fetch daily COGS for profit trend
            var cogsDataRaw = await _dbContext.InvoiceItems
                .Where(ii => ii.Invoice!.CreatedAt >= weekAgo && ii.Invoice.Status == InvoiceStatus.Completed)
                .GroupBy(ii => ii.Invoice!.CreatedAt.Date)
                .Select(g => new { Date = g.Key, TotalCogs = g.Sum(ii => Math.Round(ii.Quantity * ii.Product!.PurchasePrice, 2)) })
                .ToListAsync(cancellationToken);

            var salesTrend = new List<object>();
            for (var d = weekAgo; d <= today; d = d.AddDays(1))
            {
                var dailyTotal = salesDataRaw.FirstOrDefault(x => x.Date == d)?.Total ?? 0;
                var dailyCogs = cogsDataRaw.FirstOrDefault(x => x.Date == d)?.TotalCogs ?? 0;
                var dailyProfit = dailyTotal - dailyCogs; // Assuming daily expenses are minimal or handled monthly
                salesTrend.Add(new { Date = d.ToString("yyyy-MM-dd"), DayName = GetArabicDayName(d.DayOfWeek), Total = dailyTotal, Profit = dailyProfit });
            }

            // Daily Growth Calculate
            var yesterday = today.AddDays(-1);
            var yesterdaySales = salesDataRaw.FirstOrDefault(x => x.Date == yesterday)?.Total ?? 0;
            var dailySalesGrowth = yesterdaySales > 0 
                ? Math.Round(((double)(todaySales - yesterdaySales) / (double)yesterdaySales) * 100, 1) 
                : 0;

            // 6. Monthly Growth Metrics (this month vs previous month)
            var prevMonthStart = startOfMonth.AddMonths(-1);
            var prevMonthEnd = startOfMonth.AddSeconds(-1);

            var prevMonthSales = await _dbContext.Invoices
                .Where(i => i.CreatedAt >= prevMonthStart && i.CreatedAt <= prevMonthEnd && i.Status == InvoiceStatus.Completed)
                .SumAsync(i => i.TotalAmount, cancellationToken);

            var monthlySalesGrowth = prevMonthSales > 0
                ? Math.Round(((double)(monthlySales - prevMonthSales) / (double)prevMonthSales) * 100, 1)
                : 0;

            // 7. Monthly Advanced Financial Metrics
            var monthlyCogs = await _dbContext.InvoiceItems
                .Where(ii => ii.Invoice!.CreatedAt >= startOfMonth && ii.Invoice.Status == InvoiceStatus.Completed)
                .SumAsync(ii => Math.Round(ii.Quantity * ii.Product!.PurchasePrice, 2), cancellationToken);

            var monthlyExpenses = await _dbContext.Expenses
                .Where(e => e.Date >= startOfMonth)
                .SumAsync(e => e.Amount, cancellationToken);

            var monthlyGrossProfit = monthlySales - monthlyCogs;
            var monthlyNetProfit = monthlyGrossProfit - monthlyExpenses;

            var grossMargin = monthlySales > 0 ? Math.Round((double)(monthlyGrossProfit / monthlySales) * 100, 1) : 0;
            var netMargin = monthlySales > 0 ? Math.Round((double)(monthlyNetProfit / monthlySales) * 100, 1) : 0;
            var expenseRatio = monthlySales > 0 ? Math.Round((double)(monthlyExpenses / monthlySales) * 100, 1) : 0;

            // 8. Top 5 Profitable Products This Month
            var topProfitableProducts = await _dbContext.InvoiceItems
                .Where(ii => ii.Invoice!.CreatedAt >= startOfMonth && ii.Invoice.Status == InvoiceStatus.Completed)
                .GroupBy(ii => new { ii.ProductId, ii.Product!.Name })
                .Select(g => new
                {
                    ProductId = g.Key.ProductId,
                    ProductName = g.Key.Name,
                    TotalProfit = g.Sum(ii => Math.Round((ii.UnitPrice - ii.Product!.PurchasePrice) * ii.Quantity, 2)),
                    QuantitySold = g.Sum(ii => ii.Quantity)
                })
                .OrderByDescending(p => p.TotalProfit)
                .Take(5)
                .ToListAsync(cancellationToken);

            // 9. Installment alerts
            var overdueInstallmentsCount = await _dbContext.Installments
                .CountAsync(i => i.Status == InstallmentStatus.Pending && i.DueDate < today, cancellationToken);

            var overdueInstallmentsTotal = await _dbContext.Installments
                .Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today)
                .SumAsync(i => i.Amount, cancellationToken);

            var dueSoonCount = await _dbContext.Installments
                .CountAsync(i => i.Status == InstallmentStatus.Pending
                              && i.DueDate >= today && i.DueDate <= today.AddDays(3), cancellationToken);

            return Ok(new
            {
                TodaySales = todaySales,
                DailySalesGrowth = dailySalesGrowth, // New
                DailyInvoicesCount = dailyInvoicesCount,
                MonthlySales = monthlySales,
                MonthlySalesGrowth = monthlySalesGrowth,
                MonthlyGrossProfit = monthlyGrossProfit, // New
                MonthlyNetProfit = monthlyNetProfit,
                GrossMargin = grossMargin, // New %
                NetMargin = netMargin, // New %
                ExpenseRatio = expenseRatio, // New %
                TotalProducts = totalProducts,
                LowStockProducts = lowStockProducts,
                TotalCustomers = totalCustomers,
                OverdueInstallmentsCount = overdueInstallmentsCount,
                OverdueInstallmentsTotal = overdueInstallmentsTotal,
                DueSoonCount = dueSoonCount,
                RecentInvoices = recentInvoices,
                TopProfitableProducts = topProfitableProducts, // New
                SalesTrend = salesTrend // Now includes Profit per day
            });
        }


        private string GetArabicDayName(DayOfWeek day)
        {
            return day switch
            {
                DayOfWeek.Saturday => "السبت",
                DayOfWeek.Sunday => "الأحد",
                DayOfWeek.Monday => "الإثنين",
                DayOfWeek.Tuesday => "الثلاثاء",
                DayOfWeek.Wednesday => "الأربعاء",
                DayOfWeek.Thursday => "الخميس",
                DayOfWeek.Friday => "الجمعة",
                _ => ""
            };
        }
    }
}
