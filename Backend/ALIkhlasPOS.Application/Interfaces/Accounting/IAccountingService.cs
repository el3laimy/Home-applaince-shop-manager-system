using ALIkhlasPOS.Domain.Entities;
using System;
using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces.Accounting
{
    public interface IAccountingService
    {
        /// <summary>إنشاء قيد يومي مزدوج (مدين ودائن متساويان)</summary>
        Task<JournalEntry> CreateJournalEntryAsync(string reference, string description, string createdBy, params (Guid AccountId, decimal Debit, decimal Credit)[] lines);

        /// <summary>تسجيل مبيعات نقدية (من ح/ الخزينة إلى ح/ المبيعات)</summary>
        Task RecordCashSaleAsync(Invoice invoice, string createdBy);

        /// <summary>تسجيل سداد لمورد (من ح/ المورد إلى ح/ الخزينة)</summary>
        Task RecordSupplierPaymentAsync(Guid supplierId, decimal amount, string receiptNo, string createdBy);

        /// <summary>تسجيل مصروف تشغيلي (من ح/ المصروفات إلى ح/ الخزينة)</summary>
        Task RecordExpenseAsync(Expense expense, string createdBy);
    }
}
