using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Authorize(Roles = "Admin,Manager")]
[Route("api/[controller]")]
public class ExpensesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IAccountingService _accountingService;
    private readonly IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> _hubContext;

    public ExpensesController(ApplicationDbContext dbContext, IAccountingService accountingService, IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> hubContext)
    {
        _dbContext = dbContext;
        _accountingService = accountingService;
        _hubContext = hubContext;
    }

    [HttpGet]
    public async Task<IActionResult> GetExpenses([FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate, [FromQuery] string? categoryId, CancellationToken ct)
    {
        var start = startDate ?? DateTime.UtcNow.AddDays(-30);
        var end = endDate ?? DateTime.UtcNow;

        var query = _dbContext.Expenses
            .Include(e => e.Category)
            .Where(e => e.Date >= start && e.Date <= end);

        if (!string.IsNullOrEmpty(categoryId) && Guid.TryParse(categoryId, out var parsedCategoryId))
        {
            query = query.Where(e => e.CategoryId == parsedCategoryId);
        }

        var expenses = await query
            .OrderByDescending(e => e.Date)
            .Select(e => new
            {
                e.Id,
                e.Date,
                e.Amount,
                e.Description,
                CategoryName = e.Category.Name,
                CategoryId = e.CategoryId,
                e.CreatedBy
            })
            .ToListAsync(ct);

        return Ok(expenses);
    }


    [HttpPost]
    public async Task<IActionResult> CreateExpense([FromBody] CreateExpenseRequest request, CancellationToken ct)
    {
        if (request.Amount <= 0)
            return BadRequest("Amount must be greater than zero.");

        var category = await _dbContext.ExpenseCategories.FindAsync(request.CategoryId);
        if (category == null || !category.IsActive)
            return BadRequest("التصنيف غير موجود أو غير مفعل.");

        var expense = new Expense
        {
            Date = DateTime.UtcNow,
            Amount = request.Amount,
            CategoryId = category.Id,
            Description = request.Description,
            ReceiptImagePath = request.ReceiptImagePath,
            CreatedBy = User.Identity?.Name ?? "System"
        };

        // This records the expense to the DB AND creates the Journal/Cash transactions
        await _accountingService.RecordExpenseAsync(expense, expense.CreatedBy);

        // Trigger SignalR dashboard update
        await _hubContext.Clients.All.SendAsync("UpdateDashboard", ct);

        return CreatedAtAction(nameof(GetExpenses), new { id = expense.Id }, new
        {
            expense.Id,
            expense.Date,
            expense.Amount,
            CategoryName = category.Name,
            CategoryId = expense.CategoryId,
            expense.Description,
            expense.ReceiptImagePath,
            expense.CreatedBy
        });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteExpense(Guid id, CancellationToken ct)
    {
        var expense = await _dbContext.Expenses.FindAsync(id);
        if (expense == null)
            return NotFound(new { message = "المصروف غير موجود" });

        if (expense.JournalEntryId.HasValue)
        {
            var journal = await _dbContext.JournalEntries.FindAsync(new object[] { expense.JournalEntryId }, ct);
            if (journal != null && journal.IsClosed)
                return BadRequest(new { message = "لا يمكن حذف مصروف تم إقفاله محاسبياً" });

            var cashTx = await _dbContext.CashTransactions.FirstOrDefaultAsync(c => c.JournalEntryId == expense.JournalEntryId, ct);
            if (cashTx != null) _dbContext.CashTransactions.Remove(cashTx);

            if (journal != null)
            {
                var lines = await _dbContext.JournalEntryLines.Where(l => l.JournalEntryId == journal.Id).ToListAsync(ct);
                _dbContext.JournalEntryLines.RemoveRange(lines);
                _dbContext.JournalEntries.Remove(journal);
            }
        }

        _dbContext.Expenses.Remove(expense);
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new { message = "تم حذف المصروف بنجاح" });
    }
    [HttpPost("upload-receipt")]
    public async Task<IActionResult> UploadReceipt(IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0) return BadRequest("الملف غير صالح.");

        // Security: only allow image and PDF file types
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".pdf", ".webp" };
        var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(fileExtension))
            return BadRequest(new { message = $"نوع الملف غير مسموح. الأنواع المسموحة: {string.Join(", ", allowedExtensions)}" });

        if (file.Length > 5 * 1024 * 1024) // 5MB max
            return BadRequest(new { message = "حجم الملف يتجاوز الحد المسموح (5 ميجابايت)." });

        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "expenses");
        if (!Directory.Exists(uploadsFolder)) Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{fileExtension}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream, ct);
        }
        
        // Return relative path so frontend can append base url
        return Ok(new { Path = $"/uploads/expenses/{fileName}" });
    }
}

public class CreateExpenseRequest
{
    public decimal Amount { get; set; }
    public Guid CategoryId { get; set; }
    public string? Description { get; set; }
    public string? ReceiptImagePath { get; set; }
}
