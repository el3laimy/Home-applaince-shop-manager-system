using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public class JournalEntry
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [StringLength(50)]
        public string? VoucherNumber { get; set; } // رقم القيد (مثال: JV-2023-0001)

        public DateTime Date { get; set; } = DateTime.UtcNow;

        [StringLength(500)]
        public string? Reference { get; set; } // مرجع القيد (رقم فاتورة مثلا)

        [StringLength(500)]
        public string? Description { get; set; } // البيان

        public string CreatedBy { get; set; } = string.Empty;

        public ICollection<JournalEntryLine> Lines { get; set; } = new List<JournalEntryLine>();
    }

    public class JournalEntryLine
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid JournalEntryId { get; set; }
        public JournalEntry JournalEntry { get; set; } = null!;

        public Guid AccountId { get; set; }
        public Account? Account { get; set; }

        [StringLength(500)]
        public string? Description { get; set; } // تفاصيل السطر (شرح القيد)

        public decimal Debit { get; set; }  // مدين
        public decimal Credit { get; set; } // دائن
    }
}
