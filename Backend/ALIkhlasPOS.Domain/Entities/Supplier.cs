using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum SupplierType
    {
        Local,
        Importer
    }

    public class Supplier
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(20)]
        public string? Phone { get; set; }

        [StringLength(200)]
        public string? Address { get; set; }

        [StringLength(50)]
        public string? CompanyName { get; set; }

        public SupplierType Type { get; set; }

        public decimal OpeningBalance { get; set; } = 0; // الرصيد الافتتاحي (دائن أو مدين)

        public Guid? AccountId { get; set; } // حساب المورد في شجرة الحسابات (الخصوم)
        public Account? Account { get; set; }

        // Audit
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<PurchaseInvoice> PurchaseInvoices { get; set; } = new List<PurchaseInvoice>();
    }
}
