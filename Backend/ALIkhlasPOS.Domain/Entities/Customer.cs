namespace ALIkhlasPOS.Domain.Entities;

public class Customer
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? Notes { get; set; }

    // Financial summary (calculated fields for quick display)
    public decimal TotalPurchases { get; set; } = 0;
    public decimal TotalPaid { get; set; } = 0;
    public decimal Balance => TotalPurchases - TotalPaid; // الرصيد المتبقي

    // Navigation
    public ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();

    // Audit
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
