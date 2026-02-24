namespace ALIkhlasPOS.Domain.Entities;

public class InvoiceItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    public Guid InvoiceId { get; set; }
    public Invoice? Invoice { get; set; }
    
    public Guid ProductId { get; set; }
    public Product? Product { get; set; }
    
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice => Quantity * UnitPrice;
}
