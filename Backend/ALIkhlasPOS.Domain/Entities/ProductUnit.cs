namespace ALIkhlasPOS.Domain.Entities;

public enum UnitType
{
    Piece,
    Dozen,
    Carton
}

public class ProductUnit
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    public Guid ProductId { get; set; }
    public Product? Product { get; set; }

    public UnitType UnitType { get; set; }
    
    /// <summary>
    /// How many base pieces are in this unit. (e.g., Dozen = 12, Carton = 24)
    /// </summary>
    public int ConversionFactor { get; set; }
    
    public decimal UnitPrice { get; set; }
    
    // Optional separate barcode for a carton or a dozen
    public string? UnitBarcode { get; set; }
}
