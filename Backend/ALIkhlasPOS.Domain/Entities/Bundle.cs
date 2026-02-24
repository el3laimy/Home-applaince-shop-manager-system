namespace ALIkhlasPOS.Domain.Entities;

public class Bundle
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    
    /// <summary>
    /// For example, the Product that represents the entire "Set/Bundle".
    /// </summary>
    public Guid ParentProductId { get; set; }
    public Product? ParentProduct { get; set; }

    /// <summary>
    /// For example, a sub-item that is part of the "Set/Bundle".
    /// </summary>
    public Guid SubProductId { get; set; }
    public Product? SubProduct { get; set; }

    public int QuantityRequired { get; set; }
    public decimal DiscountAmount { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
