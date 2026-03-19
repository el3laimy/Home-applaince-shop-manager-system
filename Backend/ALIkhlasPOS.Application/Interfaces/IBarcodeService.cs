namespace ALIkhlasPOS.Application.Interfaces;

public interface IBarcodeService
{
    /// <summary>
    /// Generates a unique internal barcode using a PostgreSQL sequence.
    /// Format: 200-YYYY-NNNNN (e.g., 200-2026-00001)
    /// </summary>
    Task<string> GenerateInternalBarcodeAsync(CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Validates if a barcode string matches a known format
    /// (EAN-13, EAN-8, UPC-A, or internal 200-YYYY-NNNNN).
    /// </summary>
    bool ValidateBarcodeFormat(string barcode);

    /// <summary>
    /// Validates the EAN-13 check digit using the Modulo 10 algorithm.
    /// Returns true if the 13th digit is correct.
    /// </summary>
    bool ValidateEAN13Checksum(string barcode);

    /// <summary>
    /// Calculates the EAN-13 check digit for the first 12 digits.
    /// </summary>
    string CalculateEAN13Checksum(string first12Digits);
}
