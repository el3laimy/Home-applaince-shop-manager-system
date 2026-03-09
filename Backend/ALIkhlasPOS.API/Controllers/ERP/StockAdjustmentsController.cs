using System;
using System.Linq;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    public class StockAdjustmentDto
    {
        public Guid ProductId { get; set; }
        public StockAdjustmentType Type { get; set; }
        public int QuantityAdjusted { get; set; } // +ve or -ve
        public string Reason { get; set; } = string.Empty;
    }

    [ApiController]
    [Authorize]
    [Route("api/erp/stockadjustments")]
    public class StockAdjustmentsController : ControllerBase
    {
        private readonly ApplicationDbContext _dbContext;

        public StockAdjustmentsController(ApplicationDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] Guid? productId = null, CancellationToken ct = default)
        {
            var query = _dbContext.StockAdjustments.Include(s => s.Product).AsQueryable();
            if (productId.HasValue) query = query.Where(s => s.ProductId == productId);

            var result = await query
                .OrderByDescending(s => s.CreatedAt)
                .Select(s => new
                {
                    s.Id,
                    s.ProductId,
                    ProductName = s.Product != null ? s.Product.Name : "غير معروف",
                    s.Type,
                    TypeLabel = s.Type == StockAdjustmentType.Damage ? "هالك/توالف" : 
                               (s.Type == StockAdjustmentType.ManualCorrection ? "تسوية يدوية" : "مفقودات"),
                    s.QuantityAdjusted,
                    s.Cost,
                    s.Reason,
                    s.CreatedAt,
                    s.CreatedBy
                })
                .ToListAsync(ct);

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> CreateAdjustment([FromBody] StockAdjustmentDto dto, CancellationToken ct)
        {
            var product = await _dbContext.Products.FindAsync(new object[] { dto.ProductId }, ct);
            if (product == null) return NotFound(new { message = "المنتج غير موجود." });

            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

            // If it's damage or loss, quantity must be negative
            if ((dto.Type == StockAdjustmentType.Damage || dto.Type == StockAdjustmentType.Loss) && dto.QuantityAdjusted > 0)
            {
                dto.QuantityAdjusted = -dto.QuantityAdjusted;
            }

            if (product.StockQuantity + dto.QuantityAdjusted < 0)
            {
                return BadRequest(new { message = $"لا يمكن تسجيل توالف/فقد لعدد {Math.Abs(dto.QuantityAdjusted)} قطعة. الرصيد الحالي {product.StockQuantity} قطعة." });
            }

            // Record adjustment cost (Quantity * PurchasePrice)
            var costImpact = Math.Abs(dto.QuantityAdjusted) * product.PurchasePrice;

            var adjustment = new StockAdjustment
            {
                ProductId = dto.ProductId,
                Type = dto.Type,
                QuantityAdjusted = dto.QuantityAdjusted,
                Reason = dto.Reason,
                Cost = costImpact,
                CreatedBy = createdBy,
                CreatedAt = DateTime.UtcNow
            };

            // Update Product Stock
            product.StockQuantity += dto.QuantityAdjusted;

            _dbContext.StockAdjustments.Add(adjustment);
            _dbContext.Products.Update(product);

            // Log stock movement
            _dbContext.StockMovements.Add(new StockMovement
            {
                ProductId = product.Id,
                Type = StockMovementType.Adjustment,
                Quantity = (int)dto.QuantityAdjusted, // Can be positive or negative
                BalanceAfter = (int)product.StockQuantity,
                ReferenceId = adjustment.Id, // Note: adjustment.Id is empty Guid before save in EF Core sometimes unless Seq is used, but EF will fix it up on SaveChanges
                ReferenceNumber = $"ADJ-{DateTime.UtcNow:yyyyMMdd}-{Random.Shared.Next(100,999)}", // Temporary reference
                CreatedBy = createdBy,
                Notes = dto.Reason
            });

            // In a full ERP, we would also generate JournalEntries for inventory write-offs (Damage).
            // For now, logging the cost in StockAdjustment is sufficient for financial reports.

            await _dbContext.SaveChangesAsync(ct);

            return Ok(new { message = "تمت التسوية بنجاح.", newStock = product.StockQuantity, adjustment.Id });
        }
    }
}
