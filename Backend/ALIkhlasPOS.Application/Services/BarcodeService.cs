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
    /// Generates a sequential internal barcode using a PostgreSQL sequence.
    /// Format: 200-YYYY-NNNNN — atomic and race-condition safe.
    /// </summary>
    public async Task<string> GenerateInternalBarcodeAsync(CancellationToken cancellationToken = default)
    {
        var year = DateTime.UtcNow.Year;

        // Atomic: PostgreSQL sequence guarantees unique values across concurrent calls
        // Uses EF Core's Database facade — automatically participates in active transactions
        var result = await _dbContext.Database
            .SqlQueryRaw<long>("SELECT nextval('internal_barcode_seq') AS \"Value\"")
            .FirstAsync(cancellationToken);

        return $"200-{year}-{result:D5}";
    }

    /// <summary>
    /// Validates barcode format: EAN-13, EAN-8, UPC-A, or internal 200-YYYY-NNNNN.
    /// </summary>
    public bool ValidateBarcodeFormat(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode))
            return false;

        // EAN-13: 13 digits
        if (Regex.IsMatch(barcode, @"^\d{13}$"))
            return true;

        // EAN-8: 8 digits
        if (Regex.IsMatch(barcode, @"^\d{8}$"))
            return true;

        // UPC-A: 12 digits
        if (Regex.IsMatch(barcode, @"^\d{12}$"))
            return true;

        // Internal sequential: 200-YYYY-NNNNN
        if (Regex.IsMatch(barcode, @"^200-\d{4}-\d{5}$"))
            return true;

        // Legacy internal Code 128: starts with 200 + 7 digits
        if (Regex.IsMatch(barcode, @"^200\d{7}$"))
            return true;

        return false;
    }

    /// <summary>
    /// Validates the EAN-13 check digit using the Modulo 10 (GS1) algorithm.
    /// </summary>
    public bool ValidateEAN13Checksum(string barcode)
    {
        if (string.IsNullOrWhiteSpace(barcode) || barcode.Length != 13 || !barcode.All(char.IsDigit))
            return false;

        var first12 = barcode[..12];
        var expectedCheck = CalculateEAN13Checksum(first12);
        return barcode == expectedCheck;
    }

    /// <summary>
    /// Calculates the EAN-13 check digit for the first 12 digits.
    /// Returns the full 13-digit barcode with the correct check digit.
    /// Algorithm: GS1 Modulo 10 — odd positions ×1, even positions ×3.
    /// </summary>
    public string CalculateEAN13Checksum(string first12Digits)
    {
        if (string.IsNullOrWhiteSpace(first12Digits) || first12Digits.Length != 12 || !first12Digits.All(char.IsDigit))
            throw new ArgumentException("يجب أن يتكون الإدخال من 12 رقماً بالضبط.", nameof(first12Digits));

        int sum = 0;
        for (int i = 0; i < 12; i++)
        {
            int digit = first12Digits[i] - '0';
            // Positions: 1-indexed — odd ×1, even ×3
            sum += (i % 2 == 0) ? digit : digit * 3;
        }

        int checkDigit = (10 - (sum % 10)) % 10;
        return first12Digits + checkDigit;
    }
}
