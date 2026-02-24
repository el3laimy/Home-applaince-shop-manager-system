namespace ALIkhlasPOS.Domain.Entities;

public enum ReturnReason
{
    Defective,    // معيب
    WrongItem,    // صنف خاطئ
    CustomerChange, // تغيير رأي العميل
    Other
}

public class ReturnInvoice
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string ReturnNo { get; set; } = string.Empty;
    
    // Reference to original invoice
    public Guid OriginalInvoiceId { get; set; }
    public Invoice? OriginalInvoice { get; set; }
    
    public ReturnReason Reason { get; set; }
    public string? Notes { get; set; }
    public decimal RefundAmount { get; set; }
    
    public ICollection<ReturnInvoiceItem> Items { get; set; } = new List<ReturnInvoiceItem>();
    
    // Audit
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string CreatedBy { get; set; } = string.Empty;
}

public class ReturnInvoiceItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ReturnInvoiceId { get; set; }
    public Guid ProductId { get; set; }
    public Product? Product { get; set; }
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice => Quantity * UnitPrice;
}
