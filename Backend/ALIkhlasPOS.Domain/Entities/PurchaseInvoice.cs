using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public class PurchaseInvoice
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [StringLength(50)]
        public string? InvoiceNo { get; set; } // رقم فاتورة المورد

        public DateTime Date { get; set; } = DateTime.UtcNow;

        [Required]
        public Guid SupplierId { get; set; }
        public Supplier? Supplier { get; set; }

        public decimal TotalAmount { get; set; }
        public decimal Discount { get; set; }
        public decimal NetAmount { get; set; }     // الصافي بعد الخصم
        public decimal PaidAmount { get; set; }    // المدفوع نقداً
        public decimal RemainingAmount { get; set; } // الآجل (يضاف لرصيد المورد)

        public PurchaseInvoiceStatus Status { get; set; } = PurchaseInvoiceStatus.Completed;

        public Guid? JournalEntryId { get; set; } // تأثير الفاتورة محاسبياً
        public JournalEntry? JournalEntry { get; set; }

        public string? Notes { get; set; }
        public string CreatedBy { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<PurchaseInvoiceItem> Items { get; set; } = new List<PurchaseInvoiceItem>();
    }

    public class PurchaseInvoiceItem
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid PurchaseInvoiceId { get; set; }
        public PurchaseInvoice? PurchaseInvoice { get; set; }

        public Guid ProductId { get; set; }
        public Product? Product { get; set; }

        public decimal Quantity { get; set; }
        public decimal UnitPrice { get; set; } // سعر الشراء الجديد (يستخدم لتحديث متوسط التكلفة)
        public decimal TotalPrice { get; set; }
    }
}
