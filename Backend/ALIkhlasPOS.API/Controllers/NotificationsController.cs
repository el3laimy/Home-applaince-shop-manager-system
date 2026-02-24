using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public NotificationsController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    /// <summary>
    /// Returns a unified notifications summary: overdue installments + low-stock products.
    /// Polled every few minutes by the Flutter client.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetNotifications(CancellationToken ct)
    {
        var today = DateTime.UtcNow.Date;

        // ── Overdue Installments ─────────────────────────────────────────────
        var overdueInstallments = await _dbContext.Installments
            .Include(i => i.Invoice)
                .ThenInclude(inv => inv!.Customer)
            .Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today)
            .OrderBy(i => i.DueDate)
            .Take(20)
            .Select(i => new
            {
                i.Id,
                i.Amount,
                i.DueDate,
                DaysOverdue = (today - i.DueDate.Date).Days,
                CustomerName = i.Invoice != null && i.Invoice.Customer != null
                    ? i.Invoice.Customer.Name : "عميل نقدي",
                InvoiceNo = i.Invoice != null ? i.Invoice.InvoiceNo : ""
            })
            .ToListAsync(ct);

        var overdueTotal = overdueInstallments.Sum(i => i.Amount);

        // ── Due Soon (next 3 days) ────────────────────────────────────────────
        var dueSoon = await _dbContext.Installments
            .Include(i => i.Invoice)
                .ThenInclude(inv => inv!.Customer)
            .Where(i => i.Status == InstallmentStatus.Pending
                     && i.DueDate >= today
                     && i.DueDate <= today.AddDays(3))
            .CountAsync(ct);

        // ── Low Stock Products ────────────────────────────────────────────────
        var lowStockItems = await _dbContext.Products
            .Where(p => p.StockQuantity <= p.MinStockAlert && p.StockQuantity >= 0)
            .OrderBy(p => p.StockQuantity)
            .Take(10)
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.StockQuantity,
                p.MinStockAlert,
                p.Category
            })
            .ToListAsync(ct);

        var outOfStockCount = await _dbContext.Products
            .CountAsync(p => p.StockQuantity <= 0, ct);

        var totalUnread = overdueInstallments.Count + lowStockItems.Count;

        return Ok(new
        {
            TotalUnread = totalUnread,
            Installments = new
            {
                OverdueCount = overdueInstallments.Count,
                OverdueTotal = overdueTotal,
                DueSoonCount = dueSoon,
                Items = overdueInstallments
            },
            LowStock = new
            {
                Count = lowStockItems.Count,
                OutOfStockCount = outOfStockCount,
                Items = lowStockItems
            }
        });
    }
}
