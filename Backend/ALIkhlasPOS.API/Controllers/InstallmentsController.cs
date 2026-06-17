using System.Text;
using System.Security.Claims;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Infrastructure.Sms;
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
    private readonly SmsServiceFactory _smsFactory;
    private readonly IAccountingService _accountingService;
    private readonly IInstallmentService _installmentService;

    public InstallmentsController(ApplicationDbContext dbContext, SmsServiceFactory smsFactory, IAccountingService accountingService, IInstallmentService installmentService)
    {
        _dbContext = dbContext;
        _smsFactory = smsFactory;
        _accountingService = accountingService;
        _installmentService = installmentService;
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
            .Select(i => new
            {
                i.Id,
                i.InvoiceId,
                i.CustomerId,
                i.Amount,
                i.DueDate,
                i.Status,
                i.PaidAt,
                i.ReminderSent
            })
            .ToListAsync(cancellationToken);
        return Ok(installments);
    }

    // ── POST /api/installments/schedule ───────────────────────────────────────
    [HttpPost("schedule")]
    public async Task<IActionResult> GenerateSchedule([FromBody] GenerateScheduleDto request, CancellationToken cancellationToken)
    {
        var response = await _installmentService.GenerateScheduleAsync(request, cancellationToken);
        if (!response.Success) return BadRequest(new { message = response.Message });
        return Ok(new { message = response.Message, installmentsCount = response.InstallmentsCount });
    }

    // ── POST /api/installments/{id}/pay ───────────────────────────────────────
    [HttpPost("{id:guid}/pay")]
    public async Task<IActionResult> Pay(Guid id, [FromBody] PayInstallmentDto req, CancellationToken ct)
    {
        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";
        var response = await _installmentService.PayInstallmentAsync(id, req.AmountPaid, createdBy, ct);
        
        if (!response.Success)
        {
            if (response.Message == "Installment not found") return NotFound();
            return BadRequest(new { message = response.Message });
        }
        
        return Ok(new { message = response.Message, status = response.Status, paidAt = response.PaidAt });
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
        var response = await _installmentService.SendReminderAsync(id, ct);
        
        if (!response.Success)
        {
            if (response.Message == "Installment not found") return NotFound();
            return BadRequest(new { message = response.Message });
        }
        
        return Ok(new
        {
            message = response.Message,
            phone = response.Phone,
            dueDate = response.DueDate,
            amount = response.Amount
        });
    }

    // ── POST /api/installments/test-sms ────────────────────────────────────────
    [HttpPost("test-sms")]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> TestSms(
        [FromBody] TestSmsDto req, CancellationToken ct)
    {
        var response = await _installmentService.TestSmsAsync(req, ct);
        
        if (response.Success)
            return Ok(new { message = response.Message });
        else
            return StatusCode(500, new { message = response.Message });
    }
}

public record PayInstallmentDto(decimal AmountPaid);

public record TestSmsRequest(string Phone, string Provider, string ApiKey, string SenderId);
