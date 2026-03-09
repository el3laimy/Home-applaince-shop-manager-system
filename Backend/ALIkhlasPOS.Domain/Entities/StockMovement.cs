using System;

namespace ALIkhlasPOS.Domain.Entities;

public enum StockMovementType
{
    Sale,           // مبيعات
    Purchase,       // مشتريات
    ReturnSale,     // مرتجع مبيعات
    ReturnPurchase, // مرتجع مشتريات
    Adjustment,     // تسوية (عجز/زيادة)
    InitialBalance  // رصيد افتتاحي
}

public class StockMovement
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    // Product relationship
    public Guid ProductId { get; set; }
    public Product? Product { get; set; }

    public StockMovementType Type { get; set; }
    
    // Quantity changed (positive for Stock In, negative for Stock Out)
    public int Quantity { get; set; }
    
    // Stock amount after this movement was applied
    public int BalanceAfter { get; set; }

    // Reference ID to the document that caused it (InvoiceId, PurchaseInvoiceId, AdjustmentId)
    public Guid? ReferenceId { get; set; }
    public string? ReferenceNumber { get; set; } // e.g INV-20231005-001

    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string CreatedBy { get; set; } = string.Empty;
}
