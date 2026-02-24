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
    public class PurchaseInvoiceDto
    {
        public string? InvoiceNo { get; set; }
        public Guid SupplierId { get; set; }
        public decimal Discount { get; set; }
        public decimal PaidAmount { get; set; }
        public string? Notes { get; set; }
        public System.Collections.Generic.List<PurchaseInvoiceItemDto> Items { get; set; } = new();
    }

    public class PurchaseInvoiceItemDto
    {
        public Guid ProductId { get; set; }
        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice => Quantity * UnitPrice;
    }

    [ApiController]
    [Authorize]
    [Route("api/erp/purchases")]
    public class PurchasesController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly IAccountingService _accountingService;

        public PurchasesController(ApplicationDbContext dbContext, IAccountingService accountingService)
        {
            _dbContext = dbContext;
            _accountingService = accountingService;
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
                    p.Id, p.InvoiceNo, p.Date,
                    SupplierName = p.Supplier != null ? p.Supplier.Name : "",
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
                    Notes = dto.Notes,
                    CreatedBy = createdBy
                };

                foreach (var item in dto.Items)
                {
                    var product = await _dbContext.Products.FindAsync(item.ProductId);
                    if (product != null)
                    {
                        product.StockQuantity += item.Quantity;
                        product.PurchasePrice = item.UnitPrice; // تحديث متوسط التكلفة

                        invoice.Items.Add(new PurchaseInvoiceItem
                        {
                            ProductId = product.Id,
                            Quantity = item.Quantity,
                            UnitPrice = item.UnitPrice,
                            TotalPrice = item.TotalPrice
                        });
                    }
                }

                _dbContext.PurchaseInvoices.Add(invoice);
                await _dbContext.SaveChangesAsync();

                if (dto.PaidAmount > 0)
                    await _accountingService.RecordSupplierPaymentAsync(dto.SupplierId, dto.PaidAmount, $"PAY-{dto.InvoiceNo ?? invoice.Id.ToString()}", createdBy);

                await transaction.CommitAsync();
                return Ok(new { invoice.Id, invoice.InvoiceNo, invoice.NetAmount, invoice.RemainingAmount });
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
