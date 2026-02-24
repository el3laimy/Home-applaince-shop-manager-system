using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Domain.Entities;
using System.Security.Claims;

namespace ALIkhlasPOS.API.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ShiftsController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;

        public ShiftsController(ApplicationDbContext dbContext)
        {
            _dbContext = dbContext;
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

                return Ok(new { hasActiveShift = true, shift = activeShift });
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

                return Ok(new { message = "تم فتح الوردية بنجاح", shift });
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
                var userIdString = userId.ToString();

                // 1. Invoices
                var shiftInvoices = await _dbContext.Invoices
                    .Where(i => i.CreatedBy == userIdString && i.CreatedAt >= shift.StartTime && i.Status == InvoiceStatus.Completed)
                    .ToListAsync(cancellationToken);
                    
                shift.TotalSales = shiftInvoices.Sum(i => i.TotalAmount);
                shift.TotalCashIn = shiftInvoices.Where(i => i.PaymentType == PaymentType.Cash).Sum(i => i.TotalAmount);
                
                // 2. Installment Payments
                var shiftInstallments = await _dbContext.Installments
                    .Include(i => i.Invoice) // Include invoice to check CreatedBy
                    .Where(i => i.PaidAt != null && i.PaidAt >= shift.StartTime && i.Status == InstallmentStatus.Paid && i.Invoice!.CreatedBy == userIdString)
                    .ToListAsync(cancellationToken); 
                
                shift.TotalCashIn += shiftInstallments.Sum(i => i.Amount);

                // 3. Expenses
                var shiftExpenses = await _dbContext.Expenses
                    .Where(e => e.Date >= shift.StartTime && e.CreatedBy == userIdString)
                    .SumAsync(e => e.Amount, cancellationToken);
                
                shift.TotalCashOut += shiftExpenses;

                // 4. Return Invoices (Cash Refunds)
                var shiftReturns = await _dbContext.ReturnInvoices
                    .Where(r => r.CreatedAt >= shift.StartTime && r.CreatedBy == userIdString) // Assuming refunds are always from cash drawer
                    .SumAsync(r => r.RefundAmount, cancellationToken);
                
                shift.TotalCashOut += shiftReturns;

                // Optional: Purchasing (if Cashier pays suppliers from drawer)
                var shiftPurchases = await _dbContext.PurchaseInvoices
                    .Where(p => p.CreatedAt >= shift.StartTime && p.CreatedBy == userIdString) // Assuming cash
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
                
                // Note: Depending on accounting setup, you might want to automatically generate a JournalEntry for the difference (Shortage/Overage). For now, it stays in the Shift report.

                return Ok(new { message = "تم الإقفال بنجاح وإصدار تقرير Z", shift });
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
