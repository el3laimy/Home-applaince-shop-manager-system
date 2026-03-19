using System;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Linq;
using System.Collections.Generic;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class ReturnInvoicesController : ControllerBase
{
    // Read-only queries stay in controller; ALL write logic lives in IReturnInvoiceService.
    private readonly ApplicationDbContext _dbContext;
    private readonly IReturnInvoiceService _returnInvoiceService;

    public ReturnInvoicesController(
        ApplicationDbContext dbContext,
        IReturnInvoiceService returnInvoiceService)
    {
        _dbContext = dbContext;
        _returnInvoiceService = returnInvoiceService;
    }

    // ── Request DTOs (preserved exactly to keep Flutter JSON contract unchanged) ──
    public record ReturnItemRequest(
        Guid ProductId,
        decimal Quantity,
        Guid? ParentBundleId = null,
        decimal? CustomUnitPrice = null);

    public record CreateReturnRequest(
        Guid OriginalInvoiceId,
        ReturnReason Reason,
        string? Notes,
        List<ReturnItemRequest> Items);

    // ── GET /api/returninvoices ── list with optional search ─────────────────
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search,
        CancellationToken cancellationToken)
    {
        var query = _dbContext.ReturnInvoices
            .Include(r => r.OriginalInvoice)
                .ThenInclude(oi => oi.Customer)
            .Include(r => r.Items)
                .ThenInclude(i => i.Product)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.ToLower();
            query = query.Where(r =>
                r.ReturnNo.ToLower().Contains(s) ||
                r.OriginalInvoice.InvoiceNo.ToLower().Contains(s) ||
                (r.OriginalInvoice.Customer != null && r.OriginalInvoice.Customer.Name.ToLower().Contains(s))
            );
        }

        var returns = await query
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.Id,
                r.ReturnNo,
                r.OriginalInvoiceId,
                OriginalInvoiceNo = r.OriginalInvoice.InvoiceNo,
                CustomerName = r.OriginalInvoice.Customer != null
                    ? r.OriginalInvoice.Customer.Name
                    : "عميل نقدي",
                r.Reason,
                r.Notes,
                r.RefundAmount,
                r.CreatedBy,
                r.CreatedAt,
                Items = r.Items.Select(i => new
                {
                    i.ProductId,
                    ProductName = i.Product.Name,
                    i.Quantity,
                    i.UnitPrice,
                    i.TotalPrice
                })
            })
            .ToListAsync(cancellationToken);

        return Ok(returns);
    }

    // ── POST /api/returninvoices ── process a product return ──────────────────
    [HttpPost]
    public async Task<IActionResult> ProcessReturn(
        [FromBody] CreateReturnRequest request,
        CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

        // Map HTTP DTO → Application DTO
        var dto = new ReturnInvoiceCreateDto(
            request.OriginalInvoiceId,
            request.Reason,
            request.Notes,
            request.Items.Select(i => new ReturnInvoiceItemDto(
                i.ProductId, i.Quantity, i.ParentBundleId, i.CustomUnitPrice)).ToList()
        );

        try
        {
            var result = await _returnInvoiceService.ProcessReturnAsync(dto, createdBy, cancellationToken);

            // Exact same response shape the Flutter frontend expects
            return Ok(new
            {
                Id = result.Id,
                ReturnNo = result.ReturnNo,
                RefundAmount = result.RefundAmount,
                Message = result.Message
            });
        }
        catch (KeyNotFoundException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = $"حدث خطأ أثناء حفظ المرتجع: {ex.Message}" });
        }
    }
}
