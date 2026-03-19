using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using System.Security.Claims;

namespace ALIkhlasPOS.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ShiftsController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService _accountingService;

        public ShiftsController(ApplicationDbContext dbContext, IAccountingService accountingService)
        {
            _dbContext = dbContext;
            _accountingService = accountingService;
        }

        private Guid GetCurrentUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
                throw new UnauthorizedAccessException("المستخدم غير مصرح له.");
            return Guid.Parse(userIdClaim);
        }

        // GET: api/Shifts/current
        // Checks if the user has an active shift
        [HttpGet("current")]
        public async Task<IActionResult> GetCurrentShift(CancellationToken cancellationToken)
        {
            try
            {
                var userId = GetCurrentUserId();
                var activeShift = await _dbContext.Shifts
                    .FirstOrDefaultAsync(s => s.CashierId == userId && s.Status == ShiftStatus.Open, cancellationToken);

                if (activeShift == null)
                    return Ok(new { hasActiveShift = false });

                return Ok(new { hasActiveShift = true, shift = new {
                    activeShift.Id,
                    activeShift.CashierId,
                    activeShift.StartTime,
                    activeShift.EndTime,
                    activeShift.OpeningCash,
                    activeShift.TotalSales,
                    activeShift.TotalCashIn,
                    activeShift.TotalCashOut,
                    activeShift.ExpectedCash,
                    activeShift.ActualCash,
                    activeShift.Difference,
                    activeShift.Status,
                    activeShift.Notes
                } });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        public class OpenShiftDto
        {
            public decimal OpeningCash { get; set; }
        }

        // POST: api/Shifts/open
        [HttpPost("open")]
        public async Task<IActionResult> OpenShift([FromBody] OpenShiftDto dto, CancellationToken cancellationToken)
        {
            try
            {
                var userId = GetCurrentUserId();
                
                // Ensure no active shift exists for this user
                var existingShift = await _dbContext.Shifts
                    .AnyAsync(s => s.CashierId == userId && s.Status == ShiftStatus.Open, cancellationToken);
                    
                if (existingShift)
                    return BadRequest(new { message = "يوجد وردية مفتوحة حالياً لهذا المستخدم. يرجى إغلاقها أولاً." });

                var shift = new Shift
                {
                    Id = Guid.NewGuid(),
                    CashierId = userId,
                    StartTime = DateTime.UtcNow,
                    OpeningCash = dto.OpeningCash,
                    ExpectedCash = dto.OpeningCash, // initially expected = opening
                    Status = ShiftStatus.Open,
                    TotalSales = 0,
                    TotalCashIn = 0,
                    TotalCashOut = 0,
                    ActualCash = 0,
                    Difference = 0
                };

                _dbContext.Shifts.Add(shift);
                await _dbContext.SaveChangesAsync(cancellationToken);

                return Ok(new { message = "تم فتح الوردية بنجاح", shift = new {
                    shift.Id,
                    shift.CashierId,
                    shift.StartTime,
                    shift.EndTime,
                    shift.OpeningCash,
                    shift.TotalSales,
                    shift.TotalCashIn,
                    shift.TotalCashOut,
                    shift.ExpectedCash,
                    shift.ActualCash,
                    shift.Difference,
                    shift.Status,
                    shift.Notes
                } });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        public class CloseShiftDto
        {
            public decimal ActualCash { get; set; }
            public string? Notes { get; set; }
        }

        // POST: api/Shifts/close
        [HttpPost("close")]
        public async Task<IActionResult> CloseShift([FromBody] CloseShiftDto dto, CancellationToken cancellationToken)
        {
            try
            {
                var userId = GetCurrentUserId();
                
                var shift = await _dbContext.Shifts
                    .FirstOrDefaultAsync(s => s.CashierId == userId && s.Status == ShiftStatus.Open, cancellationToken);
                    
                if (shift == null)
                    return BadRequest(new { message = "لا توجد وردية مفتوحة لإغلاقها." });

                // Calculate totals for this shift

                // 1. Invoices — BUG-08: use CashierId (Guid) not CreatedBy (string)
                var shiftInvoices = await _dbContext.Invoices
                    .Where(i => i.CashierId == userId && i.CreatedAt >= shift.StartTime && i.Status == InvoiceStatus.Completed)
                    .ToListAsync(cancellationToken);
                    
                shift.TotalSales = shiftInvoices.Sum(i => i.TotalAmount);
                shift.TotalCashIn = shiftInvoices.Where(i => i.PaymentType == PaymentType.Cash).Sum(i => i.TotalAmount);
                
                // 2. Installment Payments
                var shiftInstallments = await _dbContext.Installments
                    .Include(i => i.Invoice)
                    .Where(i => i.PaidAt != null && i.PaidAt >= shift.StartTime && i.Status == InstallmentStatus.Paid && i.Invoice!.CashierId == userId)
                    .ToListAsync(cancellationToken); 
                
                shift.TotalCashIn += shiftInstallments.Sum(i => i.Amount);

                // 3. Expenses (only those created in this shift by this cashier)
                // NOTE: Expenses.CreatedBy stores username (from User.Identity.Name), not userId.
                var cashierUsername = User.Identity?.Name ?? "";
                var shiftExpenses = await _dbContext.Expenses
                    .Where(e => e.Date >= shift.StartTime && e.CreatedBy == cashierUsername)
                    .SumAsync(e => e.Amount, cancellationToken);
                
                shift.TotalCashOut += shiftExpenses;

                // 4. Return Invoices (Cash Refunds) — filter by CashierId on original invoice
                var shiftReturns = await _dbContext.ReturnInvoices
                    .Include(r => r.OriginalInvoice)
                    .Where(r => r.CreatedAt >= shift.StartTime && r.OriginalInvoice != null && r.OriginalInvoice.CashierId == userId)
                    .SumAsync(r => r.RefundAmount, cancellationToken);
                
                shift.TotalCashOut += shiftReturns;

                // Optional: Purchasing (if Cashier pays suppliers from drawer)
                var shiftPurchases = await _dbContext.PurchaseInvoices
                    .Where(p => p.CreatedAt >= shift.StartTime && p.CreatedBy == cashierUsername)
                    .SumAsync(p => p.PaidAmount, cancellationToken);
                
                shift.TotalCashOut += shiftPurchases;

                // Final calculations
                shift.ExpectedCash = shift.OpeningCash + shift.TotalCashIn - shift.TotalCashOut;
                shift.ActualCash = dto.ActualCash;
                shift.Difference = shift.ActualCash - shift.ExpectedCash;

                shift.EndTime = DateTime.UtcNow;
                shift.Status = ShiftStatus.Closed;
                shift.Notes = dto.Notes;

                // Save Z-Report
                await _dbContext.SaveChangesAsync(cancellationToken);
                
                // Record the Cash Shortage or Overage Journal Entry
                await _accountingService.RecordShiftClosureAsync(shift, cashierUsername);

                return Ok(new { message = "تم الإقفال بنجاح وإصدار تقرير Z", shift = new {
                    shift.Id, shift.StartTime, shift.EndTime, shift.OpeningCash,
                    shift.TotalSales, shift.TotalCashIn, shift.TotalCashOut,
                    shift.ExpectedCash, shift.ActualCash, shift.Difference,
                    shift.Status, shift.Notes
                } });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }

        // GET: api/Shifts/history
        [HttpGet("history")]
        public async Task<IActionResult> GetShiftHistory([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, CancellationToken cancellationToken)
        {
            try
            {
                var query = _dbContext.Shifts.Include(s => s.Cashier).AsQueryable();

                if (fromDate.HasValue)
                    query = query.Where(s => s.StartTime >= fromDate.Value.ToUniversalTime());
                    
                if (toDate.HasValue)
                {
                    var toDateEnd = toDate.Value.ToUniversalTime().AddDays(1).AddTicks(-1);
                    query = query.Where(s => s.StartTime <= toDateEnd);
                }

                var history = await query
                    .OrderByDescending(s => s.StartTime)
                    .Select(s => new {
                        s.Id,
                        CashierName = s.Cashier!.FullName,
                        s.StartTime,
                        s.EndTime,
                        s.OpeningCash,
                        s.ExpectedCash,
                        s.ActualCash,
                        s.Difference,
                        s.Status,
                        s.Notes
                    })
                    .ToListAsync(cancellationToken);

                return Ok(history);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"خطأ داخلي: {ex.Message}" });
            }
        }
    }
}
