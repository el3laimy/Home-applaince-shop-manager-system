using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

/// <summary>
/// Barcode utilities: batch label generation, image rendering, validation.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class BarcodeController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IBarcodeService _barcodeService;

    public BarcodeController(ApplicationDbContext dbContext, IBarcodeService barcodeService)
    {
        _dbContext = dbContext;
        _barcodeService = barcodeService;
    }

    // ── Request DTOs ─────────────────────────────────────────────────────────
    public record BatchLabelItem(Guid ProductId, int Quantity = 1);
    public record BatchLabelRequest(List<BatchLabelItem> Items, string LabelSize = "50x25");

    // ── GET /api/barcode/validate/{barcode} ──────────────────────────────────
    /// <summary>
    /// Validates a barcode string: format + EAN-13 checksum if applicable.
    /// </summary>
    [HttpGet("validate/{barcode}")]
    public IActionResult ValidateBarcode(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
            return BadRequest(new { valid = false, message = "الباركود فارغ." });

        var isValidFormat = _barcodeService.ValidateBarcodeFormat(barcode);

        // Determine type
        string type;
        if (barcode.Length == 13 && barcode.All(char.IsDigit))
            type = "EAN-13";
        else if (barcode.Length == 8 && barcode.All(char.IsDigit))
            type = "EAN-8";
        else if (barcode.Length == 12 && barcode.All(char.IsDigit))
            type = "UPC-A";
        else if (barcode.StartsWith("200-"))
            type = "Internal";
        else if (barcode.StartsWith("200") && barcode.Length == 10)
            type = "Legacy-Internal";
        else
            type = "Unknown";

        bool? checksumValid = null;
        if (type == "EAN-13")
            checksumValid = _barcodeService.ValidateEAN13Checksum(barcode);

        return Ok(new
        {
            valid = isValidFormat && (checksumValid ?? true),
            format = isValidFormat,
            checksumValid,
            type,
            barcode
        });
    }

    // ── POST /api/barcode/batch-labels ───────────────────────────────────────
    /// <summary>
    /// Returns product data for batch label printing (Frontend generates the PDF).
    /// </summary>
    [HttpPost("batch-labels")]
    public async Task<IActionResult> GetBatchLabelData(
        [FromBody] BatchLabelRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Items == null || !request.Items.Any())
            return BadRequest(new { message = "يجب تحديد منتج واحد على الأقل." });

        if (request.Items.Count > 100)
            return BadRequest(new { message = "الحد الأقصى 100 منتج في الطلب الواحد." });

        var productIds = request.Items.Select(i => i.ProductId).Distinct().ToList();
        var products = await _dbContext.Products
            .AsNoTracking()
            .Where(p => productIds.Contains(p.Id))
            .Select(p => new
            {
                p.Id,
                p.Name,
                p.Price,
                p.GlobalBarcode,
                p.InternalBarcode
            })
            .ToListAsync(cancellationToken);

        var result = request.Items.Select(item =>
        {
            var product = products.FirstOrDefault(p => p.Id == item.ProductId);
            if (product == null) return null;

            return new
            {
                product.Id,
                product.Name,
                product.Price,
                Barcode = !string.IsNullOrEmpty(product.GlobalBarcode)
                    ? product.GlobalBarcode
                    : product.InternalBarcode ?? "",
                Quantity = Math.Max(1, Math.Min(item.Quantity, 500)) // Clamp 1-500
            };
        }).Where(x => x != null).ToList();

        if (!result.Any())
            return NotFound(new { message = "لم يتم العثور على أي منتجات بالمعرفات المحددة." });

        // Parse label size
        var validSizes = new[] { "50x25", "50x30", "40x20" };
        var labelSize = validSizes.Contains(request.LabelSize) ? request.LabelSize : "50x25";

        return Ok(new
        {
            labelSize,
            totalLabels = result.Sum(r => r!.Quantity),
            products = result
        });
    }

    // ── GET /api/barcode/next ────────────────────────────────────────────────
    /// <summary>
    /// Preview the next internal barcode that will be generated.
    /// </summary>
    [HttpGet("next")]
    public async Task<IActionResult> GetNextBarcode(CancellationToken cancellationToken)
    {
        var barcode = await _barcodeService.GenerateInternalBarcodeAsync(cancellationToken);
        return Ok(new { barcode });
    }

    // ── GET /api/barcode/checksum/{first12} ──────────────────────────────────
    /// <summary>
    /// Calculate the EAN-13 check digit for 12 digits.
    /// </summary>
    [HttpGet("checksum/{first12}")]
    public IActionResult CalculateChecksum(string first12)
    {
        if (string.IsNullOrWhiteSpace(first12) || first12.Length != 12 || !first12.All(char.IsDigit))
            return BadRequest(new { message = "يجب إدخال 12 رقماً بالضبط." });

        var fullBarcode = _barcodeService.CalculateEAN13Checksum(first12);
        return Ok(new
        {
            input = first12,
            checkDigit = fullBarcode[12],
            fullBarcode
        });
    }
}
