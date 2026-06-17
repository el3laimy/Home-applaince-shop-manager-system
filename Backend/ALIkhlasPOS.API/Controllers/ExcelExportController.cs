using System.IO;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ClosedXML.Excel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin,Manager")]
public class ExcelExportController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public ExcelExportController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    // ── GET /api/excelexport/sales?from=&to= ─────────────────────────────────
    [HttpGet("sales")]
    public async Task<IActionResult> ExportSalesReport(
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null,
        CancellationToken ct = default)
    {
        var start = from ?? DateTime.UtcNow.Date.AddDays(-30);
        var end = to ?? DateTime.UtcNow;

        var invoices = await _dbContext.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Items).ThenInclude(it => it.Product)
            .Where(i => i.CreatedAt >= start && i.CreatedAt <= end && i.Status == InvoiceStatus.Completed)
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync(ct);

        var topProducts = invoices
            .SelectMany(i => i.Items)
            .GroupBy(it => it.Product?.Name ?? "غير محدد")
            .Select(g => new { Name = g.Key, Qty = g.Sum(x => x.Quantity), Revenue = g.Sum(x => x.TotalPrice) })
            .OrderByDescending(x => x.Revenue)
            .Take(15)
            .ToList();

        using var wb = new XLWorkbook();
        wb.Author = "ALIkhlasPOS";

        // ── Sheet 1: Invoices ────────────────────────────────────────────────
        var ws1 = wb.AddWorksheet("الفواتير");
        ws1.RightToLeft = true;

        // Headers
        var headers1 = new[] { "#", "رقم الفاتورة", "تاريخ الفاتورة", "العميل", "طريقة الدفع", "المجموع الفرعي", "الخصم", "الضريبة", "الإجمالي", "المدفوع", "المتبقي" };
        for (int col = 1; col <= headers1.Length; col++)
        {
            ws1.Cell(1, col).Value = headers1[col - 1];
            ws1.Cell(1, col).Style.Font.Bold = true;
            ws1.Cell(1, col).Style.Fill.BackgroundColor = XLColor.FromHtml("#1e40af");
            ws1.Cell(1, col).Style.Font.FontColor = XLColor.White;
            ws1.Cell(1, col).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        }

        // Data
        for (int i = 0; i < invoices.Count; i++)
        {
            var inv = invoices[i];
            var row = i + 2;
            ws1.Cell(row, 1).Value = i + 1;
            ws1.Cell(row, 2).Value = inv.InvoiceNo;
            ws1.Cell(row, 3).Value = inv.CreatedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
            ws1.Cell(row, 4).Value = inv.Customer?.Name ?? "عميل نقدي";
            ws1.Cell(row, 5).Value = inv.PaymentType.ToString() switch { "Cash" => "نقداً", "Card" => "بطاقة", "Installment" => "أقساط", _ => inv.PaymentType.ToString() };
            ws1.Cell(row, 6).Value = (double)inv.SubTotal;
            ws1.Cell(row, 7).Value = (double)inv.DiscountAmount;
            ws1.Cell(row, 8).Value = (double)inv.VatAmount;
            ws1.Cell(row, 9).Value = (double)inv.TotalAmount;
            ws1.Cell(row, 10).Value = (double)inv.PaidAmount;
            ws1.Cell(row, 11).Value = (double)inv.RemainingAmount;

            if (i % 2 == 0) ws1.Row(row).Style.Fill.BackgroundColor = XLColor.FromHtml("#f0f9ff");
        }

        ws1.Columns().AdjustToContents();
        var totalRow = invoices.Count + 2;
        ws1.Cell(totalRow, 4).Value = "الإجمالي";
        ws1.Cell(totalRow, 4).Style.Font.Bold = true;
        ws1.Cell(totalRow, 9).Value = (double)invoices.Sum(i => i.TotalAmount);
        ws1.Cell(totalRow, 9).Style.Font.Bold = true;
        ws1.Cell(totalRow, 9).Style.Fill.BackgroundColor = XLColor.FromHtml("#dcfce7");

        // ── Sheet 2: Top Products ────────────────────────────────────────────
        var ws2 = wb.AddWorksheet("أكثر المنتجات مبيعاً");
        ws2.RightToLeft = true;

        var headers2 = new[] { "#", "اسم المنتج", "الكمية المباعة", "إجمالي الإيرادات" };
        for (int col = 1; col <= headers2.Length; col++)
        {
            ws2.Cell(1, col).Value = headers2[col - 1];
            ws2.Cell(1, col).Style.Font.Bold = true;
            ws2.Cell(1, col).Style.Fill.BackgroundColor = XLColor.FromHtml("#7c3aed");
            ws2.Cell(1, col).Style.Font.FontColor = XLColor.White;
        }
        for (int i = 0; i < topProducts.Count; i++)
        {
            var p = topProducts[i];
            ws2.Cell(i + 2, 1).Value = i + 1;
            ws2.Cell(i + 2, 2).Value = p.Name;
            ws2.Cell(i + 2, 3).Value = p.Qty;
            ws2.Cell(i + 2, 4).Value = (double)p.Revenue;
        }
        ws2.Columns().AdjustToContents();

        // ── Sheet 3: Summary ─────────────────────────────────────────────────
        var ws3 = wb.AddWorksheet("الملخص");
        ws3.RightToLeft = true;
        ws3.Cell("A1").Value = "ALIkhlasPOS — تقرير المبيعات التلخيصي";
        ws3.Cell("A1").Style.Font.Bold = true;
        ws3.Cell("A1").Style.Font.FontSize = 14;
        ws3.Cell("A2").Value = $"الفترة: {start:yyyy-MM-dd} إلى {end:yyyy-MM-dd}";
        ws3.Cell("A4").Value = "إجمالي الفواتير"; ws3.Cell("B4").Value = invoices.Count;
        ws3.Cell("A5").Value = "إجمالي الإيرادات"; ws3.Cell("B5").Value = (double)invoices.Sum(i => i.TotalAmount);
        ws3.Cell("A6").Value = "إجمالي الخصومات"; ws3.Cell("B6").Value = (double)invoices.Sum(i => i.DiscountAmount);
        ws3.Cell("A7").Value = "إجمالي الضريبة"; ws3.Cell("B7").Value = (double)invoices.Sum(i => i.VatAmount);
        ws3.Cell("A8").Value = "إجمالي المتبقي"; ws3.Cell("B8").Value = (double)invoices.Sum(i => i.RemainingAmount);
        ws3.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        wb.SaveAs(stream);
        stream.Seek(0, SeekOrigin.Begin);

        var fileName = $"sales_report_{start:yyyyMMdd}_{end:yyyyMMdd}.xlsx";
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
    }

    // ── GET /api/excelexport/installments ────────────────────────────────────
    [HttpGet("installments")]
    public async Task<IActionResult> ExportInstallments(
        [FromQuery] string? filter = null,
        CancellationToken ct = default)
    {
        var today = DateTime.UtcNow.Date;
        var query = _dbContext.Installments
            .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
            .AsQueryable();

        if (filter == "overdue") query = query.Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today);

        var items = await query.OrderBy(i => i.DueDate).ToListAsync(ct);

        using var wb = new XLWorkbook();
        var ws = wb.AddWorksheet("الأقساط");
        ws.RightToLeft = true;

        var headers = new[] { "#", "رقم الفاتورة", "اسم العميل", "هاتف العميل", "المبلغ", "تاريخ الاستحقاق", "الحالة", "أيام التأخير", "تاريخ الدفع" };
        for (int col = 1; col <= headers.Length; col++)
        {
            ws.Cell(1, col).Value = headers[col - 1];
            ws.Cell(1, col).Style.Font.Bold = true;
            ws.Cell(1, col).Style.Fill.BackgroundColor = XLColor.FromHtml("#dc2626");
            ws.Cell(1, col).Style.Font.FontColor = XLColor.White;
        }

        for (int i = 0; i < items.Count; i++)
        {
            var item = items[i];
            var row = i + 2;
            var isOverdue = item.Status == InstallmentStatus.Pending && item.DueDate < today;
            var daysOverdue = isOverdue ? (today - item.DueDate.Date).Days : 0;
            var statusAr = item.Status switch { InstallmentStatus.Paid => "مدفوع", InstallmentStatus.Overdue => "متأخر", _ => "معلق" };

            ws.Cell(row, 1).Value = i + 1;
            ws.Cell(row, 2).Value = item.Invoice?.InvoiceNo ?? "";
            ws.Cell(row, 3).Value = item.Invoice?.Customer?.Name ?? "عميل نقدي";
            ws.Cell(row, 4).Value = item.Invoice?.Customer?.Phone ?? "";
            ws.Cell(row, 5).Value = (double)item.Amount;
            ws.Cell(row, 6).Value = item.DueDate.ToString("yyyy-MM-dd");
            ws.Cell(row, 7).Value = statusAr;
            ws.Cell(row, 8).Value = daysOverdue;
            ws.Cell(row, 9).Value = item.PaidAt?.ToString("yyyy-MM-dd") ?? "";

            if (isOverdue) ws.Row(row).Style.Fill.BackgroundColor = XLColor.FromHtml("#fef2f2");
            else if (item.Status == InstallmentStatus.Paid) ws.Row(row).Style.Fill.BackgroundColor = XLColor.FromHtml("#f0fdf4");
        }

        ws.Columns().AdjustToContents();

        using var stream = new MemoryStream();
        wb.SaveAs(stream);
        return File(stream.ToArray(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"installments_{DateTime.Now:yyyyMMdd}.xlsx");
    }
}
