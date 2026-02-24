namespace ALIkhlasPOS.Domain.Entities;

public enum InstallmentStatus
{
    Pending,
    Paid,
    Overdue
}

public class Installment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid InvoiceId { get; set; }
    public Invoice? Invoice { get; set; }
    
    public Guid CustomerId { get; set; }
    
    public decimal Amount { get; set; }
    public DateTime DueDate { get; set; }
    public InstallmentStatus Status { get; set; } = InstallmentStatus.Pending;
    public bool ReminderSent { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAt { get; set; }
}
