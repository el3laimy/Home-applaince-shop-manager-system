using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    [ApiController]
    [Authorize]
    [Route("api/erp/suppliers")]
    public class SuppliersController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;

        public SuppliersController(ApplicationDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<object>>> GetSuppliers(
            [FromQuery] string? search = null,
            CancellationToken ct = default)
        {
            var query = _dbContext.Suppliers.AsQueryable();
            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(s => s.Name.Contains(search) || (s.Phone != null && s.Phone.Contains(search)));

            var suppliers = await query.OrderBy(s => s.Name).ToListAsync(ct);

            // Augment each supplier with computed balance
            var result = new List<object>();
            foreach (var s in suppliers)
            {
                var totalPurchases = await _dbContext.PurchaseInvoices
                    .Where(p => p.SupplierId == s.Id)
                    .SumAsync(p => (decimal?)p.NetAmount, ct) ?? 0;

                var totalPayments = s.AccountId.HasValue
                    ? await _dbContext.CashTransactions
                        .Where(c => c.TargetAccountId == s.AccountId && c.Type == TransactionType.CashOut)
                        .SumAsync(c => (decimal?)c.Amount, ct) ?? 0
                    : 0;

                result.Add(new
                {
                    s.Id, s.Name, s.Phone, s.Address, s.CompanyName,
                    s.OpeningBalance, s.CreatedAt,
                    TotalPurchases = totalPurchases,
                    TotalPayments = totalPayments,
                    CurrentBalance = s.OpeningBalance + totalPurchases - totalPayments
                });
            }
            return Ok(result);
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetById(Guid id, CancellationToken ct = default)
        {
            var supplier = await _dbContext.Suppliers.FindAsync(new object[] { id }, ct);
            if (supplier == null) return NotFound();
            return Ok(supplier);
        }

        [HttpPost]
        public async Task<ActionResult<Supplier>> CreateSupplier([FromBody] Supplier supplier, CancellationToken ct = default)
        {
            supplier.CreatedAt = DateTime.UtcNow;
            _dbContext.Suppliers.Add(supplier);
            await _dbContext.SaveChangesAsync(ct);
            return CreatedAtAction(nameof(GetById), new { id = supplier.Id }, supplier);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateSupplier(Guid id, [FromBody] Supplier updated, CancellationToken ct = default)
        {
            var supplier = await _dbContext.Suppliers.FindAsync(new object[] { id }, ct);
            if (supplier == null) return NotFound();

            supplier.Name = updated.Name;
            supplier.Phone = updated.Phone;
            supplier.Address = updated.Address;
            supplier.CompanyName = updated.CompanyName;
            supplier.Type = updated.Type;
            supplier.OpeningBalance = updated.OpeningBalance;

            await _dbContext.SaveChangesAsync(ct);
            return Ok(supplier);
        }

        [HttpGet("{id:guid}/statement")]
        public async Task<IActionResult> GetSupplierStatement(Guid id, CancellationToken ct = default)
        {
            var supplier = await _dbContext.Suppliers
                .Include(s => s.PurchaseInvoices)
                .FirstOrDefaultAsync(s => s.Id == id, ct);

            if (supplier == null) return NotFound();

            var cashPayments = supplier.AccountId.HasValue
                ? await _dbContext.CashTransactions
                    .Where(c => c.TargetAccountId == supplier.AccountId && c.Type == TransactionType.CashOut)
                    .SumAsync(c => c.Amount, ct)
                : 0;

            var totalPurchased = supplier.PurchaseInvoices.Sum(p => p.NetAmount);

            return Ok(new
            {
                supplier.Name, supplier.Phone,
                OpeningBalance = supplier.OpeningBalance,
                TotalPurchases = totalPurchased,
                TotalPayments = cashPayments,
                CurrentBalance = supplier.OpeningBalance + totalPurchased - cashPayments
            });
        }

        // GET /api/erp/suppliers/{id}/invoices — Invoice history for a supplier
        [HttpGet("{id:guid}/invoices")]
        public async Task<IActionResult> GetSupplierInvoices(Guid id, CancellationToken ct = default)
        {
            var invoices = await _dbContext.PurchaseInvoices
                .Where(p => p.SupplierId == id)
                .OrderByDescending(p => p.CreatedAt)
                .Select(p => new {
                    p.Id, p.InvoiceNo, p.NetAmount, p.PaidAmount,
                    p.RemainingAmount, p.CreatedAt, p.Notes
                })
                .ToListAsync(ct);
            return Ok(invoices);
        }

        // POST /api/erp/suppliers/{id}/payment — Register a payment to a supplier
        public record SupplierPaymentRequest(decimal Amount, string? Notes);

        [HttpPost("{id:guid}/payment")]
        public async Task<IActionResult> RegisterPayment(Guid id, [FromBody] SupplierPaymentRequest req, CancellationToken ct = default)
        {
            var supplier = await _dbContext.Suppliers.FindAsync(new object[] { id }, ct);
            if (supplier == null) return NotFound();
            if (req.Amount <= 0) return BadRequest(new { message = "المبلغ يجب أن يكون أكبر من صفر." });

            // Record cash transaction
            var tx = new CashTransaction
            {
                Amount = req.Amount,
                Type = TransactionType.CashOut,
                Description = $"دفعة للمورد: {supplier.Name}",
                ReceiptNumber = $"SUP-{DateTime.UtcNow:yyyyMMddHHmmss}",
                Date = DateTime.UtcNow,
                TargetAccountId = supplier.AccountId
            };
            _dbContext.CashTransactions.Add(tx);
            await _dbContext.SaveChangesAsync(ct);

            return Ok(new { message = "تم تسجيل الدفعة بنجاح.", tx.Id, tx.Amount });
        }
    }
}
