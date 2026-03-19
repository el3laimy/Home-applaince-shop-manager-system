using ALIkhlasPOS.Domain.Entities;
using System;
using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces.Accounting
{
    public interface IAccountingService
    {
        /// <summary>إنشاء قيد يومي مزدوج (مدين ودائن متساويان)</summary>
        Task<JournalEntry> CreateJournalEntryAsync(string reference, string description, string createdBy, bool isClosed = false, params (Guid AccountId, decimal Debit, decimal Credit)[] lines);

        /// <summary>تسجيل مبيعات نقدية (من ح/ الخزينة والفيزا إلى ح/ المبيعات)</summary>
        Task RecordCashSaleAsync(Invoice invoice, string createdBy, decimal cashAmount = 0, decimal visaAmount = 0);

        /// <summary>تسجيل فاتورة مشتريات (إثبات مديونية المورد)</summary>
        Task RecordPurchaseInvoiceAsync(PurchaseInvoice invoice, string createdBy);

        /// <summary>تسجيل سداد لمورد (من ح/ المورد إلى ح/ الخزينة)</summary>
        Task RecordSupplierPaymentAsync(Guid supplierId, decimal amount, string receiptNo, string createdBy);

        /// <summary>تسجيل مصروف تشغيلي (من ح/ المصروفات إلى ح/ الخزينة)</summary>
        Task RecordExpenseAsync(Expense expense, string createdBy);

        /// <summary>تسجيل خسائر وعجز المخزون (من ح/ المصروفات إلى ح/ المخزون)</summary>
        Task RecordStockAdjustmentAsync(StockAdjustment adjustment, string createdBy);

        /// <summary>BUG-03: عكس قيد مبيعات عند المرتجع (من ح/ المبيعات إلى ح/ الخزينة)</summary>
        Task RecordSalesReturnAsync(ReturnInvoice returnInvoice, string createdBy);

        /// <summary>تسجيل دفعة قسط (من ح/ الخزينة إلى ح/ ذمم العملاء)</summary>
        Task RecordInstallmentPaymentAsync(Installment installment, decimal amountPaid, string receiptNo, string createdBy);

        /// <summary>تسجيل الفروقات المالية عند إغلاق الوردية (عجز أو زيادة نقدية)</summary>
        Task RecordShiftClosureAsync(Shift shift, string createdBy);
    }
}
