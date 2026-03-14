using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly ILogger<CustomersController> _logger; // Added

    public CustomersController(ApplicationDbContext dbContext, ILogger<CustomersController> logger) // Modified
    {
        _dbContext = dbContext;
        _logger = logger; // Added
    }

    public record CreateCustomerRequest(string Name, string? Phone, string? Address, string? Notes);
    public record UpdateCustomerRequest(string Name, string? Phone, string? Address, string? Notes);
    public record RecordPaymentRequest(decimal Amount, string? Note);

    // GET /api/customers
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 30,
        [FromQuery] string? sortBy = null,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Customers.Where(c => c.IsActive).AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(c => c.Name.Contains(search) || (c.Phone != null && c.Phone.Contains(search)));

        // Sorting
        query = sortBy switch
        {
            "balance" => query.OrderByDescending(c => c.TotalPurchases - c.TotalPaid),
            "newest" => query.OrderByDescending(c => c.CreatedAt),
            _ => query.OrderBy(c => c.Name)
        };

        var total = await query.CountAsync(cancellationToken);
        var customers = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(c => new
            {
                c.Id,
                c.Name,
                c.Phone,
                c.Address,
                c.Notes,
                c.TotalPurchases,
                c.TotalPaid,
                c.CreatedAt
            })
            .ToListAsync(cancellationToken);

        return Ok(new { total, page, pageSize, data = customers });
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers
            .Where(c => c.Id == id)
            .Select(c => new
            {
                c.Id,
                c.Name,
                c.Phone,
                c.Address,
                c.Notes,
                c.TotalPurchases,
                c.TotalPaid,
                c.CreatedAt
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (customer == null) return NotFound();
        return Ok(customer);
    }

    // POST /api/customers/rebuild-balances — Utility to fix old data
    [HttpPost("rebuild-balances")]
    public async Task<IActionResult> RebuildBalances(CancellationToken cancellationToken)
    {
        var customers = await _dbContext.Customers.ToListAsync(cancellationToken);
        int updatedCount = 0;

        foreach (var customer in customers)
        {
            var invoices = await _dbContext.Invoices
                .Where(i => i.CustomerId == customer.Id)
                .ToListAsync(cancellationToken);

            var returns = await _dbContext.ReturnInvoices
                .Include(r => r.OriginalInvoice)
                .Where(r => r.OriginalInvoice != null && r.OriginalInvoice.CustomerId == customer.Id)
                .ToListAsync(cancellationToken);

            // Re-calculate
            decimal totalPurchases = invoices.Sum(i => i.TotalAmount);
            decimal totalPaidFromInvoices = invoices.Sum(i => i.PaidAmount);
            
            // For older installments, usually PaidAmount in invoice covers the downpayment, 
            // and we rely on Installments for the rest. If TotalPaid tracks EVERYTHING, we should rebuild it from cash transactions?
            // Since TotalPaid is manually updated in newer flows, let's at least ensure TotalPurchases is correct.
            customer.TotalPurchases = totalPurchases;

            // Recalculate what they paid from actual CashTransactions connected to them?
            // We can just rely on (Invoice Downpayment + Installment Paid) for TotalPaid safely.
            var invoiceIds = invoices.Select(i => i.Id).ToList();
            var installments = await _dbContext.Installments
                .Where(inst => invoiceIds.Contains(inst.InvoiceId) && inst.Status == InstallmentStatus.Paid)
                .ToListAsync(cancellationToken);

            decimal totalPaidFromInstallments = installments.Sum(inst => inst.Amount);
            customer.TotalPaid = totalPaidFromInvoices + totalPaidFromInstallments;

            updatedCount++;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
        return Ok(new { message = $"تم إعادة بناء أرصدة {updatedCount} عميل بنجاح." });
    }

    // GET /api/customers/{id}/statement — Customer account statement
    [HttpGet("{id:guid}/statement")]
    public async Task<IActionResult> GetStatement(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();

        // 1. Invoices
        var invoices = await _dbContext.Invoices
            .Where(i => i.CustomerId == id)
            .OrderByDescending(i => i.CreatedAt)
            .Select(i => new
            {
                Type = "Invoice",
                Id = i.Id,
                Reference = i.InvoiceNo,
                Date = i.CreatedAt,
                TotalAmount = i.TotalAmount,
                PaidAmount = i.PaidAmount,
                RemainingAmount = i.RemainingAmount,
                Status = (int)i.Status,
                IsBridal = i.IsBridal
            })
            .ToListAsync(cancellationToken);

        _logger.LogDebug("Customer {CustomerId}: Found {InvoiceCount} invoices", id, invoices.Count);

        var invoiceIds = invoices.Select(i => i.Id).ToList();

        // 2. Installments
        var installments = await _dbContext.Installments
            .Where(inst => invoiceIds.Contains(inst.InvoiceId))
            .OrderByDescending(inst => inst.DueDate)
            .Select(inst => new
            {
                Type = "Installment",
                Id = inst.Id,
                Reference = inst.Invoice.InvoiceNo + " - قسط",
                Date = inst.Status == InstallmentStatus.Paid && inst.PaidAt.HasValue ? inst.PaidAt.Value : inst.DueDate,
                TotalAmount = inst.Amount,
                PaidAmount = inst.Status == InstallmentStatus.Paid ? inst.Amount : 0,
                RemainingAmount = inst.Status == InstallmentStatus.Paid ? 0 : inst.Amount,
                Status = (int)inst.Status,
                IsOverdue = inst.Status == InstallmentStatus.Pending && inst.DueDate < DateTime.UtcNow
            })
            .ToListAsync(cancellationToken);

        // 3. Return Invoices
        var returnInvoices = await _dbContext.ReturnInvoices
            .Include(r => r.OriginalInvoice)
            .Where(r => r.OriginalInvoice != null && r.OriginalInvoice.CustomerId == id)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                Type = "Return",
                Id = r.Id,
                Reference = "MR-" + r.Id.ToString().Substring(0, 8).ToUpper(),
                Date = r.CreatedAt,
                TotalAmount = r.RefundAmount,
                PaidAmount = r.RefundAmount,
                RemainingAmount = 0m,
                Status = 1, // Completed
                OriginalInvoiceNo = r.OriginalInvoice != null ? r.OriginalInvoice.InvoiceNo : string.Empty
            })
            .ToListAsync(cancellationToken);

        // Sort all timeline entries by date (strongly-typed)
        var allEntries = invoices.Select(i => new { i.Date, Entry = (object)i })
            .Concat(installments.Select(i => new { i.Date, Entry = (object)i }))
            .Concat(returnInvoices.Select(r => new { r.Date, Entry = (object)r }))
            .OrderByDescending(x => x.Date)
            .Select(x => x.Entry)
            .ToList();

        var timeline = allEntries;

        // Calculate Totals
        var totalPurchases = invoices.Sum(i => i.TotalAmount);
        var totalPaid = customer.TotalPaid; // Customer entity tracks overall paid amount accurately
        var returnsTotal = returnInvoices.Sum(r => r.TotalAmount);

        return Ok(new
        {
            Customer = new
            {
                customer.Id,
                customer.Name,
                customer.Phone,
                customer.Address,
                TotalPurchases = totalPurchases,
                TotalPaid = totalPaid,
                TotalReturns = returnsTotal,
                RemainingBalance = totalPurchases - totalPaid - returnsTotal
            },
            Timeline = timeline
        });
    }

    // GET /api/customers/{id}/statement/pdf — Export Statement as PDF
    [HttpGet("{id:guid}/statement/pdf")]
    public async Task<IActionResult> GetStatementPdf(Guid id, [FromServices] ALIkhlasPOS.Application.Services.InvoicePdfGenerator pdfGenerator, CancellationToken cancellationToken)
    {
        // Re-use the data fetching logic from GetStatement
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound(new { message = "العميل غير موجود" });

        var invoices = await _dbContext.Invoices.Where(i => i.CustomerId == id).OrderByDescending(i => i.CreatedAt)
            .Select(i => new { Type = "Invoice", Id = i.Id, Reference = i.InvoiceNo, Date = i.CreatedAt, TotalAmount = i.TotalAmount, PaidAmount = i.PaidAmount, RemainingAmount = i.RemainingAmount, Status = (int)i.Status, IsBridal = i.IsBridal })
            .ToListAsync(cancellationToken);
        var invoiceIds = invoices.Select(i => i.Id).ToList();

        var installments = await _dbContext.Installments.Where(inst => invoiceIds.Contains(inst.InvoiceId)).OrderByDescending(inst => inst.DueDate)
            .Select(inst => new { Type = "Installment", Id = inst.Id, Reference = inst.Invoice.InvoiceNo + " - قسط", Date = inst.Status == InstallmentStatus.Paid && inst.PaidAt.HasValue ? inst.PaidAt.Value : inst.DueDate, TotalAmount = inst.Amount, PaidAmount = inst.Status == InstallmentStatus.Paid ? inst.Amount : 0, RemainingAmount = inst.Status == InstallmentStatus.Paid ? 0 : inst.Amount, Status = (int)inst.Status, IsOverdue = inst.Status == InstallmentStatus.Pending && inst.DueDate < DateTime.UtcNow })
            .ToListAsync(cancellationToken);

        var returnInvoices = await _dbContext.ReturnInvoices.Include(r => r.OriginalInvoice).Where(r => r.OriginalInvoice != null && r.OriginalInvoice.CustomerId == id).OrderByDescending(r => r.CreatedAt)
            .Select(r => new { Type = "Return", Id = r.Id, Reference = "MR-" + r.Id.ToString().Substring(0, 8).ToUpper(), Date = r.CreatedAt, TotalAmount = r.RefundAmount, PaidAmount = r.RefundAmount, RemainingAmount = 0m, Status = 1, OriginalInvoiceNo = r.OriginalInvoice != null ? r.OriginalInvoice.InvoiceNo : string.Empty })
            .ToListAsync(cancellationToken);

        var timeline = new List<dynamic>();
        timeline.AddRange(invoices);
        timeline.AddRange(installments);
        timeline.AddRange(returnInvoices);
        timeline = timeline.OrderByDescending(t => (DateTime)t.Date).ToList();

        try
        {
            var pdfBytes = pdfGenerator.GenerateCustomerStatementPdf(customer, timeline);
            return File(pdfBytes, "application/pdf", $"Statement_{customer.Name.Replace(" ", "_")}.pdf");
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"خطأ أثناء توليد الـ PDF: {ex.Message}" });
        }
    }

    // GET /api/customers/{id}/invoices/{invoiceId} — Single invoice detail with items
    [HttpGet("{id:guid}/invoices/{invoiceId:guid}")]
    public async Task<IActionResult> GetInvoiceDetail(Guid id, Guid invoiceId, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices
            .Where(i => i.Id == invoiceId && i.CustomerId == id)
            .Select(i => new
            {
                i.Id,
                i.InvoiceNo,
                i.SubTotal,
                i.DiscountAmount,
                i.VatRate,
                i.VatAmount,
                i.TotalAmount,
                i.PaidAmount,
                i.RemainingAmount,
                PaymentType = (int)i.PaymentType,
                Status = (int)i.Status,
                i.CreatedAt,
                i.CreatedBy,
                Items = i.Items.Select(item => new
                {
                    item.Id,
                    item.ProductId,
                    ProductName = item.Product != null ? item.Product.Name : "",
                    item.Quantity,
                    item.UnitPrice,
                    TotalPrice = item.Quantity * item.UnitPrice
                }).ToList()
            })
            .FirstOrDefaultAsync(cancellationToken);

        if (invoice == null) return NotFound();
        return Ok(invoice);
    }

    // POST /api/customers/{id}/payment — Record a customer payment
    [HttpPost("{id:guid}/payment")]
    public async Task<IActionResult> RecordPayment(Guid id, [FromBody] RecordPaymentRequest request, CancellationToken cancellationToken)
    {
        if (request.Amount <= 0) return BadRequest(new { message = "المبلغ يجب أن يكون أكبر من صفر." });

        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();

        var balance = customer.TotalPurchases - customer.TotalPaid;
        if (request.Amount > balance)
            return BadRequest(new { message = $"المبلغ ({request.Amount:N2}) أكبر من الرصيد المستحق ({balance:N2})." });

        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // 1. Update customer TotalPaid
            customer.TotalPaid += request.Amount;

            // 2. Record CashTransaction
            var cashTx = new CashTransaction
            {
                Amount = request.Amount,
                Type = TransactionType.CashIn,
                Date = DateTime.UtcNow,
                Description = $"سداد من العميل: {customer.Name}" + (request.Note != null ? $" — {request.Note}" : ""),
                CreatedBy = createdBy
            };
            _dbContext.CashTransactions.Add(cashTx);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return Ok(new
            {
                message = "تم تسجيل الدفعة بنجاح",
                newBalance = customer.TotalPurchases - customer.TotalPaid
            });
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return BadRequest(new { message = ex.Message });
        }
    }

    // POST /api/customers
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCustomerRequest request, CancellationToken cancellationToken)
    {
        // Uniqueness check
        bool nameExists = await _dbContext.Customers.AnyAsync(c => c.Name == request.Name && c.IsActive, cancellationToken);
        if (nameExists) return BadRequest(new { message = "عذراً، يوجد عميل مسجل بهذا الاسم بالفعل." });

        if (!string.IsNullOrWhiteSpace(request.Phone))
        {
            bool phoneExists = await _dbContext.Customers.AnyAsync(c => c.Phone == request.Phone && c.IsActive, cancellationToken);
            if (phoneExists) return BadRequest(new { message = "عذراً، يوجد عميل مسجل بهذا الرقم بالفعل." });
        }

        var customer = new Customer
        {
            Name = request.Name,
            Phone = request.Phone,
            Address = request.Address,
            Notes = request.Notes
        };
        _dbContext.Customers.Add(customer);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = customer.Id }, customer);
    }

    // PUT /api/customers/{id}
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateCustomerRequest request, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();

        customer.Name = request.Name;
        customer.Phone = request.Phone;
        customer.Address = request.Address;
        customer.Notes = request.Notes;

        await _dbContext.SaveChangesAsync(cancellationToken);
        return Ok(customer);
    }

    // DELETE /api/customers/{id}
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();
        
        customer.IsActive = false;
        
        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}

