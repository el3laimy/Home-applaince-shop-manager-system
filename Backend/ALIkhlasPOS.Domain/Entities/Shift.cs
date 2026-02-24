using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum ShiftStatus
    {
        Open,
        Closed
    }

    public class Shift
    {
        [Key]
        public Guid Id { get; set; }

        public Guid CashierId { get; set; }
        
        public User? Cashier { get; set; }

        public DateTime StartTime { get; set; }

        public DateTime? EndTime { get; set; }

        public decimal OpeningCash { get; set; }

        public decimal TotalSales { get; set; }

        public decimal TotalCashIn { get; set; }

        public decimal TotalCashOut { get; set; }

        public decimal ExpectedCash { get; set; }

        public decimal ActualCash { get; set; }

        public decimal Difference { get; set; }

        public ShiftStatus Status { get; set; }

        public string? Notes { get; set; }
    }
}
