using System;
using System.Linq;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers.ERP
{
    // ── Request DTOs (kept here to preserve the exact Flutter-facing JSON schema) ──────
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
        // Only read-queries remain here; all write-logic lives in IPurchaseService.
        private readonly ApplicationDbContext _dbContext;
        private readonly IPurchaseService _purchaseService;
        private readonly IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> _hubContext;

        public PurchasesController(
            ApplicationDbContext dbContext,
            IPurchaseService purchaseService,
            IHubContext<ALIkhlasPOS.API.Hubs.DashboardHub> hubContext)
        {
            _dbContext = dbContext;
            _purchaseService = purchaseService;
            _hubContext = hubContext;
        }

        // ── GET /api/erp/purchases ── List purchase invoices ──────────────────────
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] Guid? supplierId = null, CancellationToken ct = default)
        {
            var query = _dbContext.PurchaseInvoices.Include(p => p.Supplier).AsQueryable();
            if (supplierId.HasValue)
                query = query.Where(p => p.SupplierId == supplierId);

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

        // ── POST /api/erp/purchases ── Create purchase invoice ────────────────────
        [HttpPost]
        public async Task<IActionResult> CreatePurchaseInvoice(
            [FromBody] PurchaseInvoiceDto dto,
            CancellationToken ct = default)
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

            // Map the HTTP DTO to the Application DTO
            var appDto = new PurchaseCreateDto(
                dto.InvoiceNo,
                dto.SupplierId,
                dto.Discount,
                dto.PaidAmount,
                dto.Notes,
                dto.Status,
                dto.Items.Select(i => new PurchaseItemDto(i.ProductId, i.Quantity, i.UnitCost)).ToList()
            );

            try
            {
                var result = await _purchaseService.CreatePurchaseInvoiceAsync(appDto, createdBy, ct);

                // Broadcast live dashboard update
                await _hubContext.Clients.All.SendAsync("UpdateDashboard", ct);

                // Exact same response shape as before
                return Ok(new { result.Id, result.InvoiceNo, result.NetAmount, result.RemainingAmount });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        // ── POST /api/erp/purchases/{id}/approve ── Approve Draft → Completed ─────
        [HttpPost("{id:guid}/approve")]
        public async Task<IActionResult> ApproveDraft(Guid id, CancellationToken ct = default)
        {
            var createdBy = User.FindFirstValue(ClaimTypes.Name) ?? "System";

            try
            {
                var result = await _purchaseService.ApproveDraftAsync(id, createdBy, ct);

                // Broadcast live dashboard update
                await _hubContext.Clients.All.SendAsync("UpdateDashboard", ct);

                // Exact same response shape as before
                return Ok(new { message = result.Message, Id = result.Id, Status = result.Status });
            }
            catch (KeyNotFoundException)
            {
                return NotFound();
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
