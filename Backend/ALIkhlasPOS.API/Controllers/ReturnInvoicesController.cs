using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class ReturnInvoicesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public ReturnInvoicesController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public record ReturnItemRequest(Guid ProductId, decimal Quantity);
    public record CreateReturnRequest(Guid OriginalInvoiceId, ReturnReason Reason, string? Notes, List<ReturnItemRequest> Items);

    // GET /api/returninvoices
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken cancellationToken)
    {
        var returns = await _dbContext.ReturnInvoices
            .Include(r => r.Items)
            .ThenInclude(i => i.Product)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync(cancellationToken);
        return Ok(returns);
    }

    // POST /api/returninvoices — Process a product return
    [HttpPost]
    public async Task<IActionResult> ProcessReturn([FromBody] CreateReturnRequest request, CancellationToken cancellationToken)
    {
        var originalInvoice = await _dbContext.Invoices
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == request.OriginalInvoiceId, cancellationToken);

        if (originalInvoice == null)
            return BadRequest(new { message = "الفاتورة الأصلية غير موجودة." });

        var returnInvoice = new ReturnInvoice
        {
            ReturnNo = $"RET-{DateTime.UtcNow:yyyyMMddHHmmss}",
            OriginalInvoiceId = request.OriginalInvoiceId,
            Reason = request.Reason,
            Notes = request.Notes,
            CreatedBy = "SystemUser"
        };

        foreach (var item in request.Items)
        {
            var product = await _dbContext.Products.FindAsync(new object[] { item.ProductId }, cancellationToken);
            if (product == null) return BadRequest(new { message = $"المنتج {item.ProductId} غير موجود." });

            // Restore stock
            product.StockQuantity += item.Quantity;
            _dbContext.Products.Update(product);

            returnInvoice.Items.Add(new ReturnInvoiceItem
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = product.Price
            });
        }

        returnInvoice.RefundAmount = returnInvoice.Items.Sum(i => i.TotalPrice);
        _dbContext.ReturnInvoices.Add(returnInvoice);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new
        {
            returnInvoice.Id,
            returnInvoice.ReturnNo,
            returnInvoice.RefundAmount,
            Message = "تم تسجيل المرتجع وإعادة الكميات للمخزن بنجاح."
        });
    }
}
