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
using Microsoft.AspNetCore.SignalR;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    public class PurchaseInvoiceDto
    {
        public string? InvoiceNo { get; set; }
        public Guid SupplierId { get; set; }
        public decimal Discount { get; set; }
        public decimal PaidAmount { get; set; }
        public string? Notes { get; set; }
        public string Status { get; set; } = "Completed";
        public System.Collections.Generic.List<PurchaseInvoiceItemDto> Items { get; set; } = new();
    }

    public class PurchaseInvoiceItemDto
    {
        public Guid ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitCost { get; set; }
        public decimal TotalPrice => Quantity * UnitCost;
    }

    [ApiController]
    [Authorize]
    [Route("api/erp/purchases")]
    public class PurchasesController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService _accountingService;
        private readonly IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> _hubContext;

        public PurchasesController(ApplicationDbContext dbContext, IAccountingService accountingService, IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> hubContext)
        {
            _dbContext = dbContext;
            _accountingService = accountingService;
            _hubContext = hubContext;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] Guid? supplierId = null, CancellationToken ct = default)
        {
            var query = _dbContext.PurchaseInvoices.Include(p => p.Supplier).AsQueryable();
            if (supplierId.HasValue) query = query.Where(p => p.SupplierId == supplierId);

            var result = await query
                .OrderByDescending(p => p.Date)
                .Select(p => new
                {
                    p.Id, p.InvoiceNo, CreatedAt = p.Date,
                    Supplier = new { Name = p.Supplier != null ? p.Supplier.Name : "غير معروف" },
                    p.TotalAmount, p.NetAmount, p.PaidAmount, p.RemainingAmount
                })
                .ToListAsync(ct);
            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> CreatePurchaseInvoice([FromBody] PurchaseInvoiceDto dto)
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

            using var transaction = await _dbContext.Database.BeginTransactionAsync();
            try
            {
                if (dto.PaidAmount > 0)
                {
                    var totalCash = await _dbContext.CashTransactions
                        .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount);
                    
                    if (dto.PaidAmount > totalCash)
                    {
                        return BadRequest(new { message = $"عذراً، الرصيد الحالي للخزينة ({totalCash} ج.م) لا يكفي لتسديد هذه الدفعة النقدية." });
                    }
                }

                // Determine the Status
                bool isDraft = dto.Status.Equals("Draft", StringComparison.OrdinalIgnoreCase);
                var invoiceStatus = isDraft ? PurchaseInvoiceStatus.Draft : PurchaseInvoiceStatus.Completed;

                var totalAmount = dto.Items.Sum(i => i.TotalPrice);
                var netAmount = totalAmount - dto.Discount;
                var remainingAmount = netAmount - dto.PaidAmount;

                var invoice = new PurchaseInvoice
                {
                    InvoiceNo = dto.InvoiceNo,
                    SupplierId = dto.SupplierId,
                    TotalAmount = totalAmount,
                    Discount = dto.Discount,
                    NetAmount = netAmount,
                    PaidAmount = dto.PaidAmount,
                    RemainingAmount = remainingAmount,
                    Status = invoiceStatus,
                    Notes = dto.Notes,
                    CreatedBy = createdBy
                };

                foreach (var item in dto.Items)
                {
                    var product = await _dbContext.Products.FindAsync(item.ProductId);
                    if (product != null)
                    {
                        if (!isDraft)
                        {
                            // ── Weighted Average Cost Calculation (WAC) ──
                            // WAC = ((Old Qty * Old Price) + (New Qty * New Price)) / (Old Qty + New Qty)
                            var oldTotalValue = product.StockQuantity * product.PurchasePrice;
                            var newTotalValue = item.Quantity * item.UnitCost;
                            var totalQuantity = product.StockQuantity + item.Quantity;

                            if (totalQuantity > 0)
                            {
                                product.PurchasePrice = (oldTotalValue + newTotalValue) / totalQuantity;
                            }

                            product.StockQuantity = totalQuantity;

                            _dbContext.StockMovements.Add(new StockMovement
                            {
                                ProductId = product.Id,
                                Type = StockMovementType.Purchase,
                                Quantity = (int)item.Quantity,
                                BalanceAfter = (int)product.StockQuantity,
                                ReferenceId = invoice.Id,
                                ReferenceNumber = invoice.InvoiceNo,
                                CreatedBy = createdBy
                            });
                        }
                        invoice.Items.Add(new PurchaseInvoiceItem
                        {
                            ProductId = product.Id,
                            Quantity = item.Quantity,
                            UnitPrice = item.UnitCost,
                            TotalPrice = item.TotalPrice
                        });
                    }
                }

                _dbContext.PurchaseInvoices.Add(invoice);
                await _dbContext.SaveChangesAsync();

                if (!isDraft)
                {
                    // ── إثبات مديونية المورد (التزام) وقيمة المشتريات (أصل) ──
                    await _accountingService.RecordPurchaseInvoiceAsync(invoice, createdBy);

                    // ── إذا تم دفع جزء نقداً، يتم تسجيل سداد للمورد ──
                    if (dto.PaidAmount > 0)
                        await _accountingService.RecordSupplierPaymentAsync(dto.SupplierId, dto.PaidAmount, $"PAY-{dto.InvoiceNo ?? invoice.Id.ToString()}", createdBy);
                }

                await transaction.CommitAsync();

                // Trigger SignalR dashboard update
                await _hubContext.Clients.All.SendAsync("UpdateDashboard");

                return Ok(new { invoice.Id, invoice.InvoiceNo, invoice.NetAmount, invoice.RemainingAmount });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return BadRequest(new { message = ex.Message });
            }
        }

        // FIX-F: POST /api/erp/purchases/{id}/approve — Convert Draft → Completed
        [HttpPost("{id:guid}/approve")]
        public async Task<IActionResult> ApproveDraft(Guid id)
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

            var invoice = await _dbContext.PurchaseInvoices
                .Include(p => p.Items)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (invoice == null) return NotFound();
            if (invoice.Status != PurchaseInvoiceStatus.Draft)
                return BadRequest(new { message = "هذه الفاتورة ليست مسودة — لا يمكن اعتمادها." });

            using var transaction = await _dbContext.Database.BeginTransactionAsync();
            try
            {
                // Cash check
                if (invoice.PaidAmount > 0)
                {
                    var totalCash = await _dbContext.CashTransactions
                        .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount);
                    if (invoice.PaidAmount > totalCash)
                        return BadRequest(new { message = $"رصيد الصندوق ({totalCash} ج.م) لا يكفي." });
                }

                // Apply stock + WAC
                foreach (var item in invoice.Items)
                {
                    var product = await _dbContext.Products.FindAsync(item.ProductId);
                    if (product != null)
                    {
                        var oldTotalValue = product.StockQuantity * product.PurchasePrice;
                        var newTotalValue = item.Quantity * item.UnitPrice;
                        var totalQuantity = product.StockQuantity + item.Quantity;

                        if (totalQuantity > 0)
                            product.PurchasePrice = (oldTotalValue + newTotalValue) / totalQuantity;

                        product.StockQuantity = totalQuantity;

                        _dbContext.StockMovements.Add(new StockMovement
                        {
                            ProductId = product.Id,
                            Type = StockMovementType.Purchase,
                            Quantity = (int)item.Quantity,
                            BalanceAfter = (int)product.StockQuantity,
                            ReferenceId = invoice.Id,
                            ReferenceNumber = invoice.InvoiceNo,
                            CreatedBy = createdBy
                        });
                    }
                }

                invoice.Status = PurchaseInvoiceStatus.Completed;
                await _dbContext.SaveChangesAsync();

                // Accounting
                await _accountingService.RecordPurchaseInvoiceAsync(invoice, createdBy);
                if (invoice.PaidAmount > 0)
                    await _accountingService.RecordSupplierPaymentAsync(invoice.SupplierId, invoice.PaidAmount,
                        $"PAY-{invoice.InvoiceNo ?? invoice.Id.ToString()}", createdBy);

                await transaction.CommitAsync();

                // Trigger SignalR dashboard update
                await _hubContext.Clients.All.SendAsync("UpdateDashboard");

                return Ok(new { message = "تم اعتماد الفاتورة وتحديث المخزون بنجاح.", invoice.Id, invoice.Status });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
