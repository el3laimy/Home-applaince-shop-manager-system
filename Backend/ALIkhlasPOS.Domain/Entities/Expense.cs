using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum ExpenseCategory
    {
        Operating, // مصروفات تشغيل (كهرباء، ماء)
        Salary,    // رواتب
        Marketing, // تسويق
        Other      // أخرى
    }

    public class Expense
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime Date { get; set; } = DateTime.UtcNow;

        public ExpenseCategory Category { get; set; }

        public decimal Amount { get; set; }

        [StringLength(500)]
        public string? Description { get; set; }

        public Guid? JournalEntryId { get; set; }
        public JournalEntry? JournalEntry { get; set; }

        public string CreatedBy { get; set; } = string.Empty;
    }
}
