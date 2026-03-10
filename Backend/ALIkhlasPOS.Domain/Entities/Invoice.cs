namespace ALIkhlasPOS.Domain.Entities;

public enum PaymentType
{
    Cash,
    Card,           // Old equivalent of Visa
    Installment,
    Visa,           // Credit/Debit Cards via POS machine
    BankTransfer    // InstaPay, Vodafone Cash, Bank Transfer
}

public enum InstallmentPeriod
{
    Monthly,      // شهري
    Quarterly,    // ربع سنوي
    SemiAnnual,   // نصف سنوي
    Annual        // سنوي
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

    public string? PaymentReference { get; set; } // رقم العملية لـ Visa/BankTransfer
    public string? Notes { get; set; }

    // Installment pricing fields (set when PaymentType = Installment)
    public decimal InterestRate { get; set; } = 0;            // نسبة الفائدة % على المتبقي
    public InstallmentPeriod InstallmentPeriod { get; set; } = InstallmentPeriod.Monthly; // نوع القسط
    public int InstallmentCount { get; set; } = 0;            // عدد الأقساط

    // Bridal Booking Fields
    public bool IsBridal { get; set; } = false;
    public DateTime? EventDate { get; set; }        // تاريخ الفرح
    public DateTime? DeliveryDate { get; set; }     // تاريخ التوصيل المطلوب
    public string? BridalNotes { get; set; }        // ملاحظات الحجز

    public ICollection<InvoiceItem> Items { get; set; } = new List<InvoiceItem>();

    // Audit fields
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string CreatedBy { get; set; } = string.Empty;
}
