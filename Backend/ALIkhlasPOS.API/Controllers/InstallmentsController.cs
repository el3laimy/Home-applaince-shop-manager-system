using System.Text;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class InstallmentsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public InstallmentsController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    // ── DTOs ────────────────────────────────────────────────────────────────
    public record GenerateScheduleRequest(Guid InvoiceId, Guid CustomerId, decimal DownPayment, int NumberOfMonths, DateTime FirstInstallmentDate);
    public record PayInstallmentRequest(decimal AmountPaid);

    // ── GET /api/installments — Filterable list ───────────────────────────────
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] InstallmentStatus? status = null,
        [FromQuery] Guid? customerId = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        [FromQuery] string? filter = null,     // "overdue" | "dueSoon" | "all"
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        CancellationToken ct = default)
    {
        var today = DateTime.UtcNow.Date;
        var query = _dbContext.Installments
            .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
            .AsQueryable();

        if (status.HasValue) query = query.Where(i => i.Status == status.Value);
        if (customerId.HasValue) query = query.Where(i => i.CustomerId == customerId.Value);
        if (from.HasValue) query = query.Where(i => i.DueDate >= from.Value);
        if (to.HasValue) query = query.Where(i => i.DueDate <= to.Value);

        switch (filter?.ToLower())
        {
            case "overdue":
                query = query.Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today);
                break;
            case "duesoon":
                query = query.Where(i => i.Status == InstallmentStatus.Pending && i.DueDate >= today && i.DueDate <= today.AddDays(7));
                break;
        }

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderBy(i => i.DueDate)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(i => new
            {
                i.Id,
                i.Amount,
                i.DueDate,
                i.Status,
                i.PaidAt,
                i.ReminderSent,
                DaysOverdue = i.DueDate < today && i.Status == InstallmentStatus.Pending
                    ? (today - i.DueDate.Date).Days : 0,
                CustomerName = i.Invoice != null && i.Invoice.Customer != null
                    ? i.Invoice.Customer.Name : "عميل نقدي",
                CustomerPhone = i.Invoice != null && i.Invoice.Customer != null
                    ? i.Invoice.Customer.Phone : null,
                InvoiceNo = i.Invoice != null ? i.Invoice.InvoiceNo : "",
                i.InvoiceId
            })
            .ToListAsync(ct);

        return Ok(new { total, page, pageSize, data = items });
    }

    // ── GET /api/installments/summary ─────────────────────────────────────────
    [HttpGet("summary")]
    public async Task<IActionResult> GetSummary(CancellationToken ct)
    {
        var today = DateTime.UtcNow.Date;
        var overdueCount = await _dbContext.Installments.CountAsync(i => i.Status == InstallmentStatus.Pending && i.DueDate < today, ct);
        var overdueTotal = await _dbContext.Installments.Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today).SumAsync(i => i.Amount, ct);
        var pendingTotal = await _dbContext.Installments.Where(i => i.Status == InstallmentStatus.Pending).SumAsync(i => i.Amount, ct);
        var paidTotal = await _dbContext.Installments.Where(i => i.Status == InstallmentStatus.Paid).SumAsync(i => i.Amount, ct);
        var dueSoonCount = await _dbContext.Installments.CountAsync(i => i.Status == InstallmentStatus.Pending && i.DueDate >= today && i.DueDate <= today.AddDays(7), ct);

        return Ok(new { overdueCount, overdueTotal, pendingTotal, paidTotal, dueSoonCount });
    }

    // ── GET /api/installments/invoice/{id} ────────────────────────────────────
    [HttpGet("invoice/{invoiceId:guid}")]
    public async Task<IActionResult> GetInstallmentsForInvoice(Guid invoiceId, CancellationToken cancellationToken)
    {
        var installments = await _dbContext.Installments
            .Where(i => i.InvoiceId == invoiceId)
            .OrderBy(i => i.DueDate)
            .ToListAsync(cancellationToken);
        return Ok(installments);
    }

    // ── POST /api/installments/schedule ───────────────────────────────────────
    [HttpPost("schedule")]
    public async Task<IActionResult> GenerateSchedule([FromBody] GenerateScheduleRequest request, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices.FindAsync(new object[] { request.InvoiceId }, cancellationToken);
        if (invoice == null) return NotFound("Invoice not found");
        if (invoice.PaymentType != PaymentType.Installment) return BadRequest("Invoice is not marked for installments.");

        var remainingAmount = invoice.TotalAmount - request.DownPayment;
        if (remainingAmount <= 0) return BadRequest("Down payment covers the entire invoice amount.");

        decimal monthlyAmount = Math.Round(remainingAmount / request.NumberOfMonths, 2);
        var installments = new List<Installment>();
        for (int i = 0; i < request.NumberOfMonths; i++)
        {
            decimal currentAmount = (i == request.NumberOfMonths - 1)
                ? remainingAmount - (monthlyAmount * (request.NumberOfMonths - 1))
                : monthlyAmount;
            installments.Add(new Installment
            {
                InvoiceId = invoice.Id,
                CustomerId = request.CustomerId,
                Amount = currentAmount,
                DueDate = request.FirstInstallmentDate.AddMonths(i).ToUniversalTime(),
                Status = InstallmentStatus.Pending,
                ReminderSent = false
            });
        }
        _dbContext.Installments.AddRange(installments);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return Ok(new { message = "تم إنشاء جدول الأقساط.", installmentsCount = installments.Count });
    }

    // ── POST /api/installments/{id}/pay ───────────────────────────────────────
    [HttpPost("{id:guid}/pay")]
    public async Task<IActionResult> Pay(Guid id, [FromBody] PayInstallmentRequest req, CancellationToken ct)
    {
        var installment = await _dbContext.Installments
            .Include(i => i.Invoice)
            .FirstOrDefaultAsync(i => i.Id == id, ct);

        if (installment == null) return NotFound();
        if (installment.Status == InstallmentStatus.Paid)
            return BadRequest(new { message = "هذا القسط مدفوع بالفعل." });

        installment.Status = InstallmentStatus.Paid;
        installment.PaidAt = DateTime.UtcNow;

        if (installment.Invoice != null)
        {
            installment.Invoice.PaidAmount += req.AmountPaid;
            installment.Invoice.RemainingAmount = Math.Max(0, installment.Invoice.TotalAmount - installment.Invoice.PaidAmount);
            if (installment.Invoice.RemainingAmount == 0)
                installment.Invoice.Status = InvoiceStatus.Completed;
        }

        await _dbContext.SaveChangesAsync(ct);
        return Ok(new { message = "تم تسجيل الدفعة بنجاح.", installment.Status, installment.PaidAt });
    }

    // ── GET /api/installments/export-csv ─────────────────────────────────────
    [HttpGet("export-csv")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> ExportCsv([FromQuery] string? filter = null, CancellationToken ct = default)
    {
        var today = DateTime.UtcNow.Date;
        var query = _dbContext.Installments
            .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
            .AsQueryable();

        if (filter == "overdue") query = query.Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today);

        var items = await query.OrderBy(i => i.DueDate).ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine("رقم الفاتورة,اسم العميل,هاتف العميل,المبلغ,تاريخ الاستحقاق,الحالة,أيام التأخير,تاريخ الدفع");
        foreach (var i in items)
        {
            var statusAr = i.Status switch { InstallmentStatus.Paid => "مدفوع", InstallmentStatus.Overdue => "متأخر", _ => "معلق" };
            var daysOverdue = i.Status == InstallmentStatus.Pending && i.DueDate < today ? (today - i.DueDate.Date).Days : 0;
            sb.AppendLine($"{i.Invoice?.InvoiceNo},{i.Invoice?.Customer?.Name ?? "عميل نقدي"},{i.Invoice?.Customer?.Phone ?? ""},{i.Amount},{i.DueDate:yyyy-MM-dd},{statusAr},{daysOverdue},{i.PaidAt?.ToString("yyyy-MM-dd") ?? ""}");
        }

        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
        return File(bytes, "text/csv; charset=utf-8", $"installments_{DateTime.Now:yyyyMMdd}.csv");
    }

    // ── POST /api/installments/{id}/send-reminder ─────────────────────────────
    [HttpPost("{id:guid}/send-reminder")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> SendReminder(Guid id, CancellationToken ct)
    {
        var installment = await _dbContext.Installments
            .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
            .FirstOrDefaultAsync(i => i.Id == id, ct);

        if (installment == null) return NotFound();
        var phone = installment.Invoice?.Customer?.Phone;
        if (string.IsNullOrEmpty(phone))
            return BadRequest(new { message = "العميل ليس له رقم هاتف مسجل." });

        var settings = await _dbContext.ShopSettings.FirstOrDefaultAsync(ct);
        installment.ReminderSent = true;
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new
        {
            message = $"تم إرسال تذكير للعميل {installment.Invoice?.Customer?.Name}",
            phone,
            dueDate = installment.DueDate,
            amount = installment.Amount,
            smsConfigured = !string.IsNullOrEmpty(settings?.SmsApiKey)
        });
    }
}

