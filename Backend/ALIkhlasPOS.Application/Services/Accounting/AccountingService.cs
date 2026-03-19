using System;
using System.Linq;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Application.Services.Accounting
{
    public class AccountingService : ALIkhlasPOS.Application.Interfaces.Accounting.IAccountingService
    {
        private readonly DbContext _dbContext;
        private readonly ISystemAccountService _accounts;

        public AccountingService(DbContext dbContext, ISystemAccountService accounts)
        {
            _dbContext = dbContext;
            _accounts  = accounts;
        }

        public async Task<JournalEntry> CreateJournalEntryAsync(
            string reference,
            string description,
            string createdBy,
            bool isClosed = false,
            params (Guid AccountId, decimal Debit, decimal Credit)[] lines)
        {
            var totalDebit  = lines.Sum(l => l.Debit);
            var totalCredit = lines.Sum(l => l.Credit);

            if (Math.Abs(totalDebit - totalCredit) > 0.0001m)
                throw new InvalidOperationException($"القيد غير متوازن. مدين: {totalDebit}, دائن: {totalCredit}");

            if (totalDebit == 0)
                throw new InvalidOperationException("لا يمكن إنشاء قيد بقيمة صفر.");

            // توليد رقم قيد فريد بشكل آمن عبر PostgreSQL sequence
            var nextVal = await GetNextVoucherSequenceAsync();
            var journalEntry = new JournalEntry
            {
                VoucherNumber = $"JV-{DateTime.UtcNow:yyyyMM}-{nextVal:D6}",
                Reference     = reference,
                Description   = description,
                CreatedBy     = createdBy,
                IsClosed      = isClosed,
                Date          = DateTime.UtcNow
            };

            foreach (var line in lines)
            {
                journalEntry.Lines.Add(new JournalEntryLine
                {
                    AccountId   = line.AccountId,
                    Debit       = line.Debit,
                    Credit      = line.Credit,
                    Description = description
                });
            }

            _dbContext.Set<JournalEntry>().Add(journalEntry);
            await _dbContext.SaveChangesAsync();

            return journalEntry;
        }

        public async Task RecordCashSaleAsync(Invoice invoice, string createdBy, decimal cashAmount = 0, decimal visaAmount = 0)
        {
            var cashAccountId      = await _accounts.GetSystemAccountIdAsync("CASH");
            var bankAccountId      = await _accounts.GetSystemAccountIdAsync("BANK");
            var visaAccountId      = await _accounts.GetSystemAccountIdAsync("VISA");
            var salesAccountId     = await _accounts.GetSystemAccountIdAsync("SALES");
            var cogsAccountId      = await _accounts.GetSystemAccountIdAsync("COGS");
            var inventoryAccountId = await _accounts.GetSystemAccountIdAsync("INVENTORY");

            // تحديد حساب الدفع بحسب نوع الدفع
            var targetAccountId = cashAccountId;
            string paymentDesc  = "نقدية";
            if (invoice.PaymentType == PaymentType.BankTransfer)
            {
                targetAccountId = bankAccountId;
                paymentDesc     = "تحويل بنكي";
            }
            else if (invoice.PaymentType == PaymentType.Visa || invoice.PaymentType == PaymentType.Card)
            {
                targetAccountId = visaAccountId;
                paymentDesc     = "فيزا";
            }

            bool isSplitPayment = cashAmount > 0 && visaAmount > 0;

            if (isSplitPayment)
            {
                var journal = await CreateJournalEntryAsync(
                    reference:   invoice.InvoiceNo,
                    description: $"مبيعات مقسمة (نقدي وفيزا) - فاتورة {invoice.InvoiceNo}",
                    createdBy:   createdBy,
                    false,
                    (cashAccountId,  Debit: cashAmount,           Credit: 0),
                    (visaAccountId,  Debit: visaAmount,           Credit: 0),
                    (salesAccountId, Debit: 0,                    Credit: invoice.TotalAmount)
                );

                _dbContext.Set<CashTransaction>().Add(new CashTransaction
                {
                    Amount        = cashAmount,
                    Type          = TransactionType.CashIn,
                    ReceiptNumber = invoice.InvoiceNo,
                    Description   = $"مبيعات مقسمة (نقدي) - فاتورة {invoice.InvoiceNo}",
                    TargetAccountId = salesAccountId,
                    JournalEntryId  = journal.Id,
                    CreatedBy       = createdBy,
                    Date            = DateTime.UtcNow
                });

                _dbContext.Set<CashTransaction>().Add(new CashTransaction
                {
                    Amount        = visaAmount,
                    Type          = TransactionType.CashIn,
                    ReceiptNumber = invoice.InvoiceNo,
                    Description   = $"مبيعات مقسمة (فيزا) - فاتورة {invoice.InvoiceNo}",
                    TargetAccountId = salesAccountId,
                    JournalEntryId  = journal.Id,
                    CreatedBy       = createdBy,
                    Date            = DateTime.UtcNow
                });
            }
            else if (invoice.PaymentType == PaymentType.Installment && invoice.RemainingAmount > 0)
            {
                var arAccountId          = await _accounts.GetSystemAccountIdAsync("ACCOUNTS_RECEIVABLE");
                var downPaymentAccount   = visaAmount > 0 ? visaAccountId : cashAccountId;

                var journal = await CreateJournalEntryAsync(
                    reference:   invoice.InvoiceNo,
                    description: $"مبيعات بالتقسيط - فاتورة {invoice.InvoiceNo}",
                    createdBy:   createdBy,
                    false,
                    (downPaymentAccount, Debit: invoice.PaidAmount,     Credit: 0),
                    (arAccountId,        Debit: invoice.RemainingAmount, Credit: 0),
                    (salesAccountId,     Debit: 0,                       Credit: invoice.TotalAmount)
                );

                if (invoice.PaidAmount > 0)
                {
                    _dbContext.Set<CashTransaction>().Add(new CashTransaction
                    {
                        Amount        = invoice.PaidAmount,
                        Type          = TransactionType.CashIn,
                        ReceiptNumber = invoice.InvoiceNo,
                        Description   = $"مقدم أقساط - فاتورة {invoice.InvoiceNo}",
                        TargetAccountId = salesAccountId,
                        JournalEntryId  = journal.Id,
                        CreatedBy       = createdBy,
                        Date            = DateTime.UtcNow
                    });
                }
            }
            else
            {
                decimal actualPaidAmount = invoice.TotalAmount;

                var journal = await CreateJournalEntryAsync(
                    reference:   invoice.InvoiceNo,
                    description: $"مبيعات {paymentDesc} - فاتورة {invoice.InvoiceNo}",
                    createdBy:   createdBy,
                    false,
                    (targetAccountId, Debit: actualPaidAmount, Credit: 0),
                    (salesAccountId,  Debit: 0,                Credit: actualPaidAmount)
                );

                if (actualPaidAmount > 0)
                {
                    _dbContext.Set<CashTransaction>().Add(new CashTransaction
                    {
                        Amount        = actualPaidAmount,
                        Type          = TransactionType.CashIn,
                        ReceiptNumber = invoice.InvoiceNo,
                        Description   = $"مبيعات {paymentDesc} - فاتورة {invoice.InvoiceNo}",
                        TargetAccountId = salesAccountId,
                        JournalEntryId  = journal.Id,
                        CreatedBy       = createdBy,
                        Date            = DateTime.UtcNow
                    });
                }
            }

            // إثبات تكلفة البضاعة المباعة (COGS)
            decimal actualCost = 0;
            if (invoice.Items != null && invoice.Items.Any())
            {
                foreach (var item in invoice.Items)
                {
                    var product = await _dbContext.Set<Product>().FindAsync(item.ProductId);
                    if (product != null)
                        actualCost += product.PurchasePrice * item.Quantity;
                }
            }

            if (actualCost > 0)
            {
                await CreateJournalEntryAsync(
                    reference:   invoice.InvoiceNo,
                    description: $"إثبات تكلفة البضاعة المباعة لفاتورة {invoice.InvoiceNo}",
                    createdBy:   createdBy,
                    false,
                    (cogsAccountId,      Debit: actualCost, Credit: 0),
                    (inventoryAccountId, Debit: 0,          Credit: actualCost)
                );
            }
        }

        public async Task RecordPurchaseInvoiceAsync(PurchaseInvoice invoice, string createdBy)
        {
            var inventoryAccountId      = await _accounts.GetSystemAccountIdAsync("INVENTORY");
            var supplierControlAccountId = await _accounts.GetSystemAccountIdAsync("SUPPLIERS_CONTROL");

            var supplier     = await _dbContext.Set<Supplier>().FindAsync(invoice.SupplierId);
            var supplierName = supplier?.Name ?? "مورد غير معروف";

            if (invoice.NetAmount > 0)
            {
                await CreateJournalEntryAsync(
                    reference:   invoice.InvoiceNo ?? $"PI-{invoice.Id.ToString()[..8]}",
                    description: $"فاتورة مشتريات من المورد: {supplierName}",
                    createdBy:   createdBy,
                    false,
                    (inventoryAccountId,       Debit: invoice.NetAmount, Credit: 0),
                    (supplierControlAccountId, Debit: 0,                 Credit: invoice.NetAmount)
                );
            }
        }

        public async Task RecordSupplierPaymentAsync(Guid supplierId, decimal amount, string receiptNo, string createdBy)
        {
            var cashAccountId            = await _accounts.GetSystemAccountIdAsync("CASH");
            var supplierControlAccountId = await _accounts.GetSystemAccountIdAsync("SUPPLIERS_CONTROL");

            var supplier = await _dbContext.Set<Supplier>().FindAsync(supplierId);
            if (supplier == null) throw new Exception("المورد غير موجود.");

            var journal = await CreateJournalEntryAsync(
                reference:   receiptNo,
                description: $"دفعة نقدية للمورد {supplier.Name}",
                createdBy:   createdBy,
                false,
                (supplierControlAccountId, Debit: amount, Credit: 0),
                (cashAccountId,            Debit: 0,      Credit: amount)
            );

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount          = amount,
                Type            = TransactionType.CashOut,
                ReceiptNumber   = receiptNo,
                Description     = $"سداد للمورد {supplier.Name}",
                TargetAccountId = supplierControlAccountId,
                JournalEntryId  = journal.Id,
                CreatedBy       = createdBy
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordExpenseAsync(Expense expense, string createdBy)
        {
            var cashAccountId     = await _accounts.GetSystemAccountIdAsync("CASH");
            var expensesAccountId = await _accounts.GetSystemAccountIdAsync("OPERATING_EXPENSES");

            var journal = await CreateJournalEntryAsync(
                reference:   $"EXP-{DateTime.UtcNow:yyyyMMdd}-{expense.Id}",
                description: expense.Description ?? "مصروف",
                createdBy:   createdBy,
                false,
                (expensesAccountId, Debit: expense.Amount, Credit: 0),
                (cashAccountId,     Debit: 0,              Credit: expense.Amount)
            );

            expense.JournalEntryId = journal.Id;
            _dbContext.Set<Expense>().Add(expense);

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount          = expense.Amount,
                Type            = TransactionType.CashOut,
                ReceiptNumber   = $"REC-{DateTime.UtcNow:yyyyMMdd}-{expense.Id}",
                Description     = expense.Description,
                TargetAccountId = expensesAccountId,
                JournalEntryId  = journal.Id,
                CreatedBy       = createdBy
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordStockAdjustmentAsync(StockAdjustment adjustment, string createdBy)
        {
            var inventoryAccountId = await _accounts.GetSystemAccountIdAsync("INVENTORY");
            var spoilageAccountId  = await _accounts.GetSystemAccountIdAsync("SPOILAGE_EXPENSES");

            if (adjustment.Cost > 0)
            {
                await CreateJournalEntryAsync(
                    reference:   $"ADJ-{adjustment.Id.ToString()[..8]}",
                    description: $"تسوية عجز/تلف مخزون: {adjustment.Reason}",
                    createdBy:   createdBy,
                    false,
                    (spoilageAccountId,  Debit: adjustment.Cost, Credit: 0),
                    (inventoryAccountId, Debit: 0,               Credit: adjustment.Cost)
                );
            }
        }

        public async Task RecordSalesReturnAsync(ReturnInvoice returnInvoice, string createdBy)
        {
            if (returnInvoice.RefundAmount <= 0) return;

            var cashAccountId      = await _accounts.GetSystemAccountIdAsync("CASH");
            var salesAccountId     = await _accounts.GetSystemAccountIdAsync("SALES");
            var inventoryAccountId = await _accounts.GetSystemAccountIdAsync("INVENTORY");
            var cogsAccountId      = await _accounts.GetSystemAccountIdAsync("COGS");

            var journal = await CreateJournalEntryAsync(
                reference:   returnInvoice.ReturnNo,
                description: $"مرتجع مبيعات - {returnInvoice.ReturnNo}",
                createdBy:   createdBy,
                false,
                (salesAccountId, Debit: returnInvoice.RefundAmount, Credit: 0),
                (cashAccountId,  Debit: 0,                          Credit: returnInvoice.RefundAmount)
            );

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount          = returnInvoice.RefundAmount,
                Type            = TransactionType.CashOut,
                ReceiptNumber   = returnInvoice.ReturnNo,
                Description     = $"استرجاع مبيعات - {returnInvoice.ReturnNo}",
                TargetAccountId = salesAccountId,
                JournalEntryId  = journal.Id,
                CreatedBy       = createdBy,
                Date            = DateTime.UtcNow
            });

            decimal returnedCost = 0;
            if (returnInvoice.Items != null && returnInvoice.Items.Any())
            {
                foreach (var item in returnInvoice.Items)
                {
                    var product = await _dbContext.Set<Product>().FindAsync(item.ProductId);
                    if (product != null)
                        returnedCost += product.PurchasePrice * item.Quantity;
                }
            }

            if (returnedCost > 0)
            {
                await CreateJournalEntryAsync(
                    reference:   returnInvoice.ReturnNo,
                    description: $"استعادة تكلفة مخزون مرتجع - {returnInvoice.ReturnNo}",
                    createdBy:   createdBy,
                    false,
                    (inventoryAccountId, Debit: returnedCost, Credit: 0),
                    (cogsAccountId,      Debit: 0,            Credit: returnedCost)
                );
            }

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordInstallmentPaymentAsync(Installment installment, decimal amountPaid, string receiptNo, string createdBy)
        {
            var cashAccountId = await _accounts.GetSystemAccountIdAsync("CASH");
            var arAccountId   = await _accounts.GetSystemAccountIdAsync("ACCOUNTS_RECEIVABLE");

            var journal = await CreateJournalEntryAsync(
                reference:   receiptNo,
                description: $"تحصيل قسط - {receiptNo}",
                createdBy:   createdBy,
                false,
                (cashAccountId, Debit: amountPaid, Credit: 0),
                (arAccountId,   Debit: 0,          Credit: amountPaid)
            );

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount          = amountPaid,
                Type            = TransactionType.CashIn,
                ReceiptNumber   = receiptNo,
                Description     = $"تحصيل قسط - {receiptNo}",
                TargetAccountId = arAccountId,
                JournalEntryId  = journal.Id,
                CreatedBy       = createdBy,
                Date            = DateTime.UtcNow
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordShiftClosureAsync(Shift shift, string createdBy)
        {
            if (shift.Difference == 0) return;

            var cashAccountId = await _accounts.GetSystemAccountIdAsync("CASH");

            if (shift.Difference < 0)
            {
                var shortageAccountId = await _accounts.GetSystemAccountIdAsync("SPOILAGE_EXPENSES");
                decimal shortageAmount = Math.Abs(shift.Difference);

                await CreateJournalEntryAsync(
                    reference:   $"SHIFT-{shift.Id.ToString()[..8]}",
                    description: $"عجز في الوردية الدفترية ({shift.Id.ToString()[..8]})",
                    createdBy:   createdBy,
                    false,
                    (shortageAccountId, Debit: shortageAmount, Credit: 0),
                    (cashAccountId,     Debit: 0,              Credit: shortageAmount)
                );
            }
            else
            {
                var otherRevenueAccountId = await _accounts.GetSystemAccountIdAsync("OTHER_REVENUES");

                await CreateJournalEntryAsync(
                    reference:   $"SHIFT-{shift.Id.ToString()[..8]}",
                    description: $"زيادة في الوردية الدفترية ({shift.Id.ToString()[..8]})",
                    createdBy:   createdBy,
                    false,
                    (cashAccountId,        Debit: shift.Difference, Credit: 0),
                    (otherRevenueAccountId, Debit: 0,               Credit: shift.Difference)
                );
            }
        }

        // ── مساعد: الرقم التسلسلي لـ VoucherNumber من PostgreSQL sequence ──────
        private async Task<long> GetNextVoucherSequenceAsync()
        {
            var result = await _dbContext.Database
                .SqlQueryRaw<long>("SELECT nextval('voucher_seq') AS \"Value\"")
                .FirstAsync();
            return result;
        }
    }
}
