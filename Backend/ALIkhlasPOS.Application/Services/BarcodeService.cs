using System.Text.RegularExpressions;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Application.Services;

public class BarcodeService : IBarcodeService
{
    private readonly DbContext _dbContext;

    public BarcodeService(DbContext dbContext)
    {
        _dbContext = dbContext;
    }

    /// <summary>
    /// Generates a sequential internal barcode in the format: 200-YYYY-NNNNN
    /// Example: 200-2026-00001, 200-2026-00002, ...
    /// Prefix 200 = internal store code
    /// YYYY    = current year (enables per-year sequences)
    /// NNNNN   = 5-digit sequence (up to 99,999 products/year)
    /// </summary>
    public async Task<string> GenerateInternalBarcodeAsync(CancellationToken cancellationToken = default)
    {
        var year = DateTime.UtcNow.Year;
        var prefix = $"200-{year}-";

        // Find the highest existing sequence number for this year
        var lastBarcode = await _dbContext.Set<Product>()
            .Where(p => p.InternalBarcode != null && p.InternalBarcode.StartsWith(prefix))
            .Select(p => p.InternalBarcode!)
            .OrderByDescending(b => b)
            .FirstOrDefaultAsync(cancellationToken);

        int nextSeq = 1;
        if (lastBarcode != null)
        {
            var parts = lastBarcode.Split('-');
            if (parts.Length == 3 && int.TryParse(parts[2], out int lastSeq))
                nextSeq = lastSeq + 1;
        }

        return $"{prefix}{nextSeq:D5}";
    }

    public bool ValidateBarcodeFormat(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
            return false;

        // EAN-13 format: 13 digits
        var ean13Regex = new Regex(@"^\d{13}$");
        // New sequential internal format: 200-YYYY-NNNNN
        var sequentialRegex = new Regex(@"^200-\d{4}-\d{5}$");
        // Legacy internal Code 128 format: starts with 200 + 7 digits
        var legacyRegex = new Regex(@"^200\d{7}$");

        return ean13Regex.IsMatch(barcode) || sequentialRegex.IsMatch(barcode) || legacyRegex.IsMatch(barcode);
    }
}
