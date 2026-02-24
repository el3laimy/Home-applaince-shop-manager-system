using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    [ApiController]
    [Authorize]
    [Route("api/erp/finance")]
    public class FinanceController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService _accountingService;

        public FinanceController(ApplicationDbContext dbContext, IAccountingService accountingService)
        {
            _dbContext = dbContext;
            _accountingService = accountingService;
        }

        [HttpGet("dashboard")]
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

            return Ok(new
            {
                TotalCash = totalCash,
                TodayExpenses = todayExpenses,
                TodaySales = todaySales,
                TotalInventoryValue = inventoryValue,
                PendingSupplierBalance = pendingSupplierBalance
            });
        }

        [HttpPost("expenses")]
        public async Task<IActionResult> RecordExpense([FromBody] Expense expense)
        {
            try
            {
                expense.CreatedBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
                await _accountingService.RecordExpenseAsync(expense, expense.CreatedBy);
                return Ok(expense);
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpGet("expenses")]
        public async Task<IActionResult> GetExpenses([FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null, CancellationToken ct = default)
        {
            var start = from ?? DateTime.UtcNow.AddDays(-30);
            var end = to ?? DateTime.UtcNow;

            var expenses = await _dbContext.Expenses
                .Where(e => e.Date >= start && e.Date <= end)
                .OrderByDescending(e => e.Date)
                .ToListAsync(ct);

            return Ok(new
            {
                Total = expenses.Sum(e => e.Amount),
                Data = expenses
            });
        }

        [HttpGet("cash-flow")]
        public async Task<IActionResult> GetCashFlows([FromQuery] int limit = 50, CancellationToken ct = default)
        {
            var flows = await _dbContext.CashTransactions
                .OrderByDescending(c => c.Date)
                .Take(limit)
                .ToListAsync(ct);

            return Ok(flows);
        }

        [HttpPost("period-close")]
        public async Task<IActionResult> ClosePeriod()
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
            using var transaction = await _dbContext.Database.BeginTransactionAsync();
            try
            {
                var salesAccId = await GetSystemAccountIdAsync("SALES");
                var cogsAccId = await GetSystemAccountIdAsync("COGS");
                var expAccId = await GetSystemAccountIdAsync("OPERATING_EXPENSES");
                var equityAccId = await GetSystemAccountIdAsync("EQUITY_CAPITAL");

                var salesBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == salesAccId).SumAsync(l => l.Credit - l.Debit);
                var cogsBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == cogsAccId).SumAsync(l => l.Debit - l.Credit);
                var expensesBalance = await _dbContext.JournalEntryLines
                    .Where(l => l.AccountId == expAccId).SumAsync(l => l.Debit - l.Credit);

                decimal netIncome = salesBalance - (cogsBalance + expensesBalance);

                if (netIncome != 0)
                {
                    await _accountingService.CreateJournalEntryAsync(
                        reference: $"CLOSE-{DateTime.UtcNow:yyyyMM}",
                        description: "إقفال الفترة وترحيل صافي الربح لرأس المال",
                        createdBy: createdBy,
                        (salesAccId, Debit: salesBalance, Credit: 0),
                        (cogsAccId, Debit: 0, Credit: cogsBalance),
                        (expAccId, Debit: 0, Credit: expensesBalance),
                        (equityAccId, Debit: netIncome < 0 ? Math.Abs(netIncome) : 0, Credit: netIncome > 0 ? netIncome : 0)
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

        private async Task<Guid> GetSystemAccountIdAsync(string systemCode)
        {
            var acc = await _dbContext.Set<Account>().FirstOrDefaultAsync(a => a.Code == systemCode);
            if (acc == null)
            {
                acc = new Account
                {
                    Code = systemCode,
                    Name = systemCode switch
                    {
                        "EQUITY_CAPITAL" => "رأس المال",
                        _ => $"حساب نظام - {systemCode}"
                    },
                    Type = systemCode == "EQUITY_CAPITAL" ? AccountType.Equity : AccountType.Asset
                };
                _dbContext.Set<Account>().Add(acc);
                await _dbContext.SaveChangesAsync();
            }
            return acc.Id;
        }
    }
}
