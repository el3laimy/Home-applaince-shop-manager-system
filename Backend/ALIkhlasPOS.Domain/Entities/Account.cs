using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    public enum AccountType
    {
        Asset,       // أصول (خزينة، بنك، عملاء، مخزون)
        Liability,   // خصوم (موردين، قروض)
        Equity,      // حقوق ملكية (رأس مال، أرباح محتجزة)
        Revenue,     // إيرادات (مبيعات)
        Expense      // مصروفات (مشتريات، إيجار، رواتب)
    }

    public class Account
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [StringLength(50)]
        public string Code { get; set; } = string.Empty; // رقم الحساب (مثال: 1001)

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty; // اسم الحساب (الخزينة الرئيسية)

        public AccountType Type { get; set; }

        public bool IsActive { get; set; } = true;

        // Self-referencing hierarchy (رأسي أم فرعي)
        public Guid? ParentAccountId { get; set; }
        public Account? ParentAccount { get; set; }
        public ICollection<Account> SubAccounts { get; set; } = new List<Account>();

        public ICollection<JournalEntryLine> JournalLines { get; set; } = new List<JournalEntryLine>();
    }
}
