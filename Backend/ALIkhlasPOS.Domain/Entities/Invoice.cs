namespace ALIkhlasPOS.Domain.Entities;

public enum PaymentType
{
    Cash,
    Card,
    Installment
}

public enum InvoiceStatus
{
    Completed,
    Reserved // For Bridal reservations where items are set aside but not fully paid yet
}

public class Invoice
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string InvoiceNo { get; set; } = string.Empty;

    // Customer link (optional — null means cash sale with no registered customer)
    public Guid? CustomerId { get; set; }
    public Customer? Customer { get; set; }

    // Cashier who processed this sale
    public Guid? CashierId { get; set; }

    // Financial fields
    public decimal SubTotal { get; set; }      // الإجمالي قبل الخصم
    public decimal DiscountAmount { get; set; } // قيمة الخصم
    public decimal VatRate { get; set; } = 0;   // نسبة الضريبة (0 = بدون ضريبة)
    public decimal VatAmount { get; set; }       // قيمة الضريبة المحسوبة
    public decimal TotalAmount { get; set; }     // الإجمالي بعد الخصم + الضريبة

    // Payment tracking (for installments)
    public decimal PaidAmount { get; set; }      // المبلغ المسدد نقداً عند إنشاء الفاتورة
    public decimal RemainingAmount { get; set; } // المتبقي (يُسدَّد بالأقساط)

    public PaymentType PaymentType { get; set; }
    public InvoiceStatus Status { get; set; } = InvoiceStatus.Completed;

    public string? Notes { get; set; }

    public ICollection<InvoiceItem> Items { get; set; } = new List<InvoiceItem>();

    // Audit fields
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string CreatedBy { get; set; } = string.Empty;
}
