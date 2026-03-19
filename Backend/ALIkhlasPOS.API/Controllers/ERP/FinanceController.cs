using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    [ApiController]
    [Authorize]
    [Route("api/erp/finance")]
    [EnableRateLimiting("financial")]
    public class FinanceController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService   _accountingService;
        private readonly ISystemAccountService _accounts;

        public FinanceController(
            ApplicationDbContext dbContext,
            IAccountingService accountingService,
            ISystemAccountService accounts)
        {
            _dbContext         = dbContext;
            _accountingService = accountingService;
            _accounts          = accounts;
        }

        [HttpGet("summary")]
        public async Task<IActionResult> GetFinanceDashboard()
        {
            var totalCash = await _dbContext.CashTransactions
                .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount);

            var todayExpenses = await _dbContext.Expenses
                .Where(e => e.Date.Date == DateTime.UtcNow.Date)
                .SumAsync(e => e.Amount);

            var todaySales = await _dbContext.Invoices
                .Where(i => i.CreatedAt.Date == DateTime.UtcNow.Date && i.Status == InvoiceStatus.Completed)
                .SumAsync(i => i.TotalAmount);

            var inventoryValue = await _dbContext.Products
                .SumAsync(p => p.StockQuantity * p.PurchasePrice);

            var pendingSupplierBalance = await _dbContext.PurchaseInvoices
                .SumAsync(p => p.RemainingAmount);

            var treasuryAccId = await _accounts.GetSystemAccountIdAsync("MAIN_TREASURY");
            var mainTreasuryBalance = await _dbContext.JournalEntryLines
                .Where(l => l.AccountId == treasuryAccId)
                .SumAsync(l => l.Debit - l.Credit);

            return Ok(new
            {
                CashDrawerBalance      = totalCash,
                MainTreasuryBalance    = mainTreasuryBalance,
                TodayExpenses          = todayExpenses,
                TodaySales             = todaySales,
                TotalInventoryValue    = inventoryValue,
                PendingSupplierBalance = pendingSupplierBalance
            });
        }

        [HttpGet("safe-balance")]
        public async Task<IActionResult> GetSafeBalance()
        {
            var totalCash = await _dbContext.CashTransactions
                .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount);

            return Ok(new { SafeBalance = totalCash });
        }

        public record CreateExpenseRequest(Guid CategoryId, decimal Amount, string Description);

        [HttpPost("expenses")]
        public async Task<IActionResult> RecordExpense([FromBody] CreateExpenseRequest request)
        {
            try
            {
                var category = await _dbContext.ExpenseCategories.FindAsync(request.CategoryId);
                if (category == null || !category.IsActive)
                    return BadRequest(new { message = "التصنيف غير موجود أو غير مفعل." });

                var expense = new Expense
                {
                    CategoryId  = category.Id,
                    Amount      = request.Amount,
                    Description = request.Description,
                    Date        = DateTime.UtcNow,
                    CreatedBy   = User.FindFirstValue(ClaimTypes.Name) ?? "System"
                };

                await _accountingService.RecordExpenseAsync(expense, expense.CreatedBy);
                return Ok(expense);
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("expenses")]
        public async Task<IActionResult> GetExpenses(
            [FromQuery] DateTime? from = null,
            [FromQuery] DateTime? to   = null,
            CancellationToken ct = default)
        {
            var start = from ?? DateTime.UtcNow.AddDays(-30);
            var end   = to   ?? DateTime.UtcNow;

            var expenses = await _dbContext.Expenses
                .Include(e => e.Category)
                .Where(e => e.Date >= start && e.Date <= end)
                .OrderByDescending(e => e.Date)
                .ToListAsync(ct);

            return Ok(new
            {
                Total = expenses.Sum(e => e.Amount),
                Data  = expenses.Select(e => new
                {
                    e.Id,
                    e.Amount,
                    e.Description,
                    e.Date,
                    e.CreatedBy,
                    e.CategoryId,
                    CategoryName = e.Category != null ? e.Category.Name : "غير مصنف"
                })
            });
        }

        public record TransferToTreasuryRequest(decimal Amount, string? Description);

        [HttpPost("transfer-to-treasury")]
        public async Task<IActionResult> TransferToTreasury([FromBody] TransferToTreasuryRequest request)
        {
            var totalCash = await _dbContext.CashTransactions
                .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount);

            if (request.Amount <= 0)
                return BadRequest(new { message = "المبلغ غير صالح." });
            if (request.Amount > totalCash)
                return BadRequest(new { message = "رصيد الدرج لا يكفي للتحويل." });

            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
            using var transaction = await _dbContext.Database.BeginTransactionAsync();
            try
            {
                // 1. الخصم من الكاشير (درج الصندوق)
                var cashOut = new CashTransaction
                {
                    Amount      = request.Amount,
                    Type        = TransactionType.CashOut,
                    Date        = DateTime.UtcNow,
                    Description = request.Description ?? "توريد نقدية للخزينة الرئيسية",
                    CreatedBy   = createdBy
                };
                _dbContext.CashTransactions.Add(cashOut);

                // 2. القيد المحاسبي
                var mainAccId   = await _accounts.GetSystemAccountIdAsync("MAIN_TREASURY");
                var drawerAccId = await _accounts.GetSystemAccountIdAsync("CASH");

                await _accountingService.CreateJournalEntryAsync(
                    $"TRF-{DateTime.UtcNow:yyyyMMddHHmm}",
                    request.Description ?? "توريد للخزينة الرئيسية",
                    createdBy,
                    false,
                    (mainAccId,   request.Amount, 0),
                    (drawerAccId, 0,              request.Amount)
                );

                await _dbContext.SaveChangesAsync();
                await transaction.CommitAsync();

                return Ok(new { message = "تم التحويل بنجاح" });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("cash-transactions")]
        public async Task<IActionResult> GetCashFlows(
            [FromQuery] string? period = null,
            [FromQuery] int limit      = 50,
            CancellationToken ct = default)
        {
            var flows = _dbContext.CashTransactions.AsQueryable();
            if (period == "today")
                flows = flows.Where(c => c.Date.Date == DateTime.UtcNow.Date);

            var result = await flows
                .OrderByDescending(c => c.Date)
                .Take(limit)
                .Select(c => new
                {
                    Time        = c.Date.ToString("HH:mm"),
                    ReferenceNo = c.ReceiptNumber,
                    Type        = c.Type == TransactionType.CashIn ? "in" : "out",
                    TypeName    = c.Type == TransactionType.CashIn ? "قبض نقدية" : "صرف نقدية",
                    Description = c.Description,
                    Amount      = c.Amount
                })
                .ToListAsync(ct);

            return Ok(new { data = result });
        }

        [HttpPost("close-period")]
        public async Task<IActionResult> ClosePeriod()
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
            using var transaction = await _dbContext.Database.BeginTransactionAsync();
            try
            {
                var salesAccId  = await _accounts.GetSystemAccountIdAsync("SALES");
                var cogsAccId   = await _accounts.GetSystemAccountIdAsync("COGS");
                var expAccId    = await _accounts.GetSystemAccountIdAsync("OPERATING_EXPENSES");
                var equityAccId = await _accounts.GetSystemAccountIdAsync("EQUITY_CAPITAL");

                var salesBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == salesAccId && !l.JournalEntry.IsClosed)
                    .SumAsync(l => l.Credit - l.Debit);

                var cogsBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == cogsAccId && !l.JournalEntry.IsClosed)
                    .SumAsync(l => l.Debit - l.Credit);

                var expensesBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == expAccId && !l.JournalEntry.IsClosed)
                    .SumAsync(l => l.Debit - l.Credit);

                decimal netIncome = salesBalance - (cogsBalance + expensesBalance);

                if (netIncome != 0)
                {
                    var unclosedEntries = await _dbContext.JournalEntries
                        .Where(j => !j.IsClosed)
                        .ToListAsync();

                    foreach (var entry in unclosedEntries)
                        entry.IsClosed = true;

                    await _accountingService.CreateJournalEntryAsync(
                        $"CLOSE-{DateTime.UtcNow:yyyyMMddHHmm}",
                        "إقفال الفترة وترحيل صافي الربح لرأس المال",
                        createdBy,
                        true,
                        (salesAccId,  salesBalance,                        0),
                        (cogsAccId,   0,                                   cogsBalance),
                        (expAccId,    0,                                   expensesBalance),
                        (equityAccId, netIncome < 0 ? Math.Abs(netIncome) : 0,
                                      netIncome > 0 ? netIncome : 0)
                    );
                }

                await transaction.CommitAsync();
                return Ok(new { Message = "تم إقفال الفترة بنجاح", NetIncome = netIncome });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
