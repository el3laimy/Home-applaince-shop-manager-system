using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public class Expense
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime Date { get; set; } = DateTime.UtcNow;

        public Guid CategoryId { get; set; }
        public ExpenseCategory? Category { get; set; }

        public decimal Amount { get; set; }

        [StringLength(500)]
        public string? Description { get; set; }

        public string? ReceiptImagePath { get; set; }

        public Guid? JournalEntryId { get; set; }
        public JournalEntry? JournalEntry { get; set; }

        public string CreatedBy { get; set; } = string.Empty;
    }
}
