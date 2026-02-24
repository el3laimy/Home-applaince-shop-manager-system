namespace ALIkhlasPOS.Application.Interfaces;

public interface IBarcodeService
{
    /// <summary>
    /// Generates a unique internal barcode (Code 128) for products without a global barcode.
    /// </summary>
    Task<string> GenerateInternalBarcodeAsync(CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Validates if a barcode is a valid EAN-13 or Code 128 format.
    /// </summary>
    bool ValidateBarcodeFormat(string barcode);
}
