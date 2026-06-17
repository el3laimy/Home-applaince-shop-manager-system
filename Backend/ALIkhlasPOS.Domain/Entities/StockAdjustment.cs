using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum StockAdjustmentType
    {
        Damage,           // توالف (هالك)
        ManualCorrection, // تصحيح يدوي للمخزون
        Loss              // فقدان
    }

    public class StockAdjustment
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid ProductId { get; set; }
        public Product? Product { get; set; }

        public StockAdjustmentType Type { get; set; }

        public int QuantityAdjusted { get; set; } // Can be positive or negative

        public decimal Cost { get; set; } // The cost impact (Quantity * PurchasePrice)

        [Required]
        [MaxLength(500)]
        public string Reason { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [Required]
        [MaxLength(100)]
        public string CreatedBy { get; set; } = string.Empty;
    }
}
