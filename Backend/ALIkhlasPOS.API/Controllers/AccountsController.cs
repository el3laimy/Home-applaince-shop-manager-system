using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Domain.Entities;
using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces.Accounting;

namespace ALIkhlasPOS.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class AccountsController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService _accountingService;

        public AccountsController(ApplicationDbContext dbContext, IAccountingService accountingService)
        {
            _dbContext = dbContext;
            _accountingService = accountingService;
        }

        private string GetCurrentUsername()
        {
            return User.Identity?.Name ?? "System";
        }

        // GET: api/accounts/coa
        [HttpGet("coa")]
        public async Task<IActionResult> GetChartOfAccounts(CancellationToken cancellationToken)
        {
            try
            {
                var accounts = await _dbContext.Accounts
                    .Where(a => a.IsActive)
                    .OrderBy(a => a.Code)
                    .Select(a => new
                    {
                        a.Id,
                        a.Code,
                        a.Name,
                        Type = a.Type.ToString(),
                        a.ParentAccountId
                    })
                    .ToListAsync(cancellationToken);

                return Ok(accounts);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        // GET: api/accounts/trial-balance
        [HttpGet("trial-balance")]
        public async Task<IActionResult> GetTrialBalance([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, CancellationToken cancellationToken)
        {
            try
            {
                var query = _dbContext.JournalEntryLines
                    .Include(l => l.Account)
                    .Include(l => l.JournalEntry)
                    .AsQueryable();

                if (fromDate.HasValue)
                    query = query.Where(l => l.JournalEntry.Date >= fromDate.Value);
                if (toDate.HasValue)
                    query = query.Where(l => l.JournalEntry.Date <= toDate.Value);

                var trialBalance = await query
                    .GroupBy(l => new { l.AccountId, l.Account!.Code, l.Account.Name, l.Account.Type })
                    .Select(g => new
                    {
                        AccountId = g.Key.AccountId,
                        Code = g.Key.Code,
                        Name = g.Key.Name,
                        Type = g.Key.Type.ToString(),
                        TotalDebit = g.Sum(l => l.Debit),
                        TotalCredit = g.Sum(l => l.Credit),
                        Balance = g.Sum(l => l.Debit) - g.Sum(l => l.Credit) // Positive = Debit Balance, Negative = Credit Balance
                    })
                    .Where(a => a.TotalDebit > 0 || a.TotalCredit > 0)
                    .OrderBy(a => a.Code)
                    .ToListAsync(cancellationToken);

                var totalDebit = trialBalance.Sum(a => a.TotalDebit);
                var totalCredit = trialBalance.Sum(a => a.TotalCredit);
                var isBalanced = Math.Abs(totalDebit - totalCredit) < 0.01m;

                return Ok(new
                {
                    accounts = trialBalance,
                    totalDebit,
                    totalCredit,
                    isBalanced
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        // GET: api/accounts/{id}/ledger
        [HttpGet("{id}/ledger")]
        public async Task<IActionResult> GetAccountLedger(Guid id, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, CancellationToken cancellationToken)
        {
            try
            {
                // Verify account exists
                var account = await _dbContext.Accounts.FindAsync(id);
                if (account == null) return NotFound(new { message = "الحساب غير موجود." });

                var query = _dbContext.JournalEntryLines
                    .Include(l => l.JournalEntry)
                    .Where(l => l.AccountId == id)
                    .AsQueryable();

                if (fromDate.HasValue)
                    query = query.Where(l => l.JournalEntry.Date >= fromDate.Value);
                if (toDate.HasValue)
                    query = query.Where(l => l.JournalEntry.Date <= toDate.Value);

                var lines = await query
                    .OrderBy(l => l.JournalEntry.Date)
                    .Select(l => new
                    {
                        l.Id,
                        Date = l.JournalEntry.Date,
                        VoucherNumber = l.JournalEntry.VoucherNumber,
                        Description = l.Description ?? l.JournalEntry.Description,
                        Reference = l.JournalEntry.Reference,
                        l.Debit,
                        l.Credit
                    })
                    .ToListAsync(cancellationToken);

                decimal runningBalance = 0;
                var resList = new List<object>();

                foreach (var line in lines)
                {
                    runningBalance += (line.Debit - line.Credit);
                    resList.Add(new
                    {
                        line.Id,
                        line.Date,
                        line.VoucherNumber,
                        line.Description,
                        line.Reference,
                        line.Debit,
                        line.Credit,
                        Balance = runningBalance
                    });
                }

                return Ok(new
                {
                    accountName = account.Name,
                    accountCode = account.Code,
                    transactions = resList,
                    finalBalance = runningBalance
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        // GET: api/accounts/income-statement
        [HttpGet("income-statement")]
        public async Task<IActionResult> GetIncomeStatement([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, CancellationToken cancellationToken)
        {
            try
            {
                var query = _dbContext.JournalEntryLines
                    .Include(l => l.Account)
                    .Include(l => l.JournalEntry)
                    .Where(l => l.Account!.Type == AccountType.Revenue || l.Account.Type == AccountType.Expense)
                    .AsQueryable();

                if (fromDate.HasValue) query = query.Where(l => l.JournalEntry.Date >= fromDate.Value);
                if (toDate.HasValue) query = query.Where(l => l.JournalEntry.Date <= toDate.Value);

                var balances = await query
                    .GroupBy(l => new { l.AccountId, l.Account!.Code, l.Account.Name, l.Account.Type, l.Account.ParentAccountId })
                    .Select(g => new
                    {
                        AccountId = g.Key.AccountId,
                        Code = g.Key.Code,
                        Name = g.Key.Name,
                        Type = g.Key.Type,
                        ParentId = g.Key.ParentAccountId,
                        TotalDebit = g.Sum(l => l.Debit),
                        TotalCredit = g.Sum(l => l.Credit),
                        Balance = g.Key.Type == AccountType.Revenue 
                            ? g.Sum(l => l.Credit) - g.Sum(l => l.Debit) // Revenue normal balance is Credit
                            : g.Sum(l => l.Debit) - g.Sum(l => l.Credit) // Expense normal balance is Debit
                    })
                    .ToListAsync(cancellationToken);

                var revenues = balances.Where(b => b.Type == AccountType.Revenue).OrderBy(b => b.Code).ToList();
                var expenses = balances.Where(b => b.Type == AccountType.Expense).OrderBy(b => b.Code).ToList();

                var totalRevenue = revenues.Sum(r => r.Balance);
                var totalExpense = expenses.Sum(e => e.Balance);
                
                // P&L
                var netIncome = totalRevenue - totalExpense;

                return Ok(new
                {
                    revenues,
                    totalRevenue,
                    expenses,
                    totalExpense,
                    netIncome
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        // GET: api/accounts/balance-sheet
        [HttpGet("balance-sheet")]
        public async Task<IActionResult> GetBalanceSheet([FromQuery] DateTime? asOfDate, CancellationToken cancellationToken)
        {
            try
            {
                var query = _dbContext.JournalEntryLines
                    .Include(l => l.Account)
                    .Include(l => l.JournalEntry)
                    .Where(l => l.Account!.Type == AccountType.Asset || l.Account.Type == AccountType.Liability || l.Account.Type == AccountType.Equity)
                    .AsQueryable();

                if (asOfDate.HasValue)
                {
                    query = query.Where(l => l.JournalEntry.Date <= asOfDate.Value);
                }

                var balances = await query
                    .GroupBy(l => new { l.AccountId, l.Account!.Code, l.Account.Name, l.Account.Type })
                    .Select(g => new
                    {
                        AccountId = g.Key.AccountId,
                        Code = g.Key.Code,
                        Name = g.Key.Name,
                        Type = g.Key.Type,
                        Balance = g.Key.Type == AccountType.Asset
                            ? g.Sum(l => l.Debit) - g.Sum(l => l.Credit) // Assets normal balance is Debit
                            : g.Sum(l => l.Credit) - g.Sum(l => l.Debit) // Liability/Equity normal balance is Credit
                    })
                    .ToListAsync(cancellationToken);

                var assets = balances.Where(b => b.Type == AccountType.Asset).OrderBy(b => b.Code).ToList();
                var liabilities = balances.Where(b => b.Type == AccountType.Liability).OrderBy(b => b.Code).ToList();
                var equity = balances.Where(b => b.Type == AccountType.Equity).OrderBy(b => b.Code).ToList();

                var totalAssets = assets.Sum(a => a.Balance);
                var totalLiabilities = liabilities.Sum(l => l.Balance);
                var totalEquity = equity.Sum(e => e.Balance);

                return Ok(new
                {
                    assets,
                    totalAssets,
                    liabilities,
                    totalLiabilities,
                    equity,
                    totalEquity,
                    isBalanced = Math.Abs(totalAssets - (totalLiabilities + totalEquity)) < 0.01m
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        public class ManualJournalEntryDto
        {
            public string Description { get; set; } = string.Empty;
            public string? Reference { get; set; }
            public List<JournalLineDto> Lines { get; set; } = new();
        }

        public class JournalLineDto
        {
            public Guid AccountId { get; set; }
            public decimal Debit { get; set; }
            public decimal Credit { get; set; }
        }

        // POST: api/accounts/journal-entry
        [HttpPost("journal-entry")]
        public async Task<IActionResult> CreateManualEntry([FromBody] ManualJournalEntryDto dto)
        {
            try
            {
                if (dto.Lines.Count < 2)
                    return BadRequest(new { message = "يجب أن يحتوي القيد على سطرين على الأقل (مدين ودائن)." });

                var mappedLines = dto.Lines.Select(l => (l.AccountId, l.Debit, l.Credit)).ToArray();

                var journalEntry = await _accountingService.CreateJournalEntryAsync(
                    reference: dto.Reference ?? string.Empty,
                    description: dto.Description,
                    createdBy: GetCurrentUsername(),
                    isClosed: true,
                    lines: mappedLines
                );

                return Ok(new { message = "تم حفظ القيد بنجاح.", voucherNumber = journalEntry.VoucherNumber });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }
    }
}
