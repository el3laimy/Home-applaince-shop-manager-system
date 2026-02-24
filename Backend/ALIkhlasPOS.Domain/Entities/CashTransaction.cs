using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum TransactionType
    {
        CashIn,  // قبض (من مبيعات أو عميل)
        CashOut  // صرف (لمورد أو مصروف)
    }

    public class CashTransaction
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime Date { get; set; } = DateTime.UtcNow;

        [StringLength(50)]
        public string? ReceiptNumber { get; set; } // رقم الإيصال

        public TransactionType Type { get; set; }

        public decimal Amount { get; set; }

        [StringLength(500)]
        public string? Description { get; set; } // سبب الحركة

        // مرجع للحساب المتأثر في شجرة الحسابات
        public Guid? TargetAccountId { get; set; }
        public Account? TargetAccount { get; set; }

        public Guid? JournalEntryId { get; set; }
        public JournalEntry? JournalEntry { get; set; }

        public string CreatedBy { get; set; } = string.Empty;
    }
}
