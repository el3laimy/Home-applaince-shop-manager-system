using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities;

public class Product
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? GlobalBarcode { get; set; }
    public string? InternalBarcode { get; set; }
    public string? Description { get; set; }

    // Multiple Pricing Levels
    public decimal PurchasePrice { get; set; } // سعر الشراء (متوسط التكلفة)
    public decimal WholesalePrice { get; set; } // سعر الجملة
    public decimal Price { get; set; } // سعر التجزئة (البيع العادي)

    public decimal StockQuantity { get; set; }
    public decimal MinStockAlert { get; set; } = 5; // حد التنبيه للنواقص
    public DateTime? ExpiryDate { get; set; }

    [StringLength(100)]
    public string? Category { get; set; }

    /// <summary>Relative URL to product image served via StaticFiles, e.g. /uploads/products/abc.jpg</summary>
    public string? ImageUrl { get; set; }

    // Audit fields
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
