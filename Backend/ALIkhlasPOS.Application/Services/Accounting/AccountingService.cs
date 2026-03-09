using System;
using System.Linq;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Application.Services.Accounting
{
    public class AccountingService : ALIkhlasPOS.Application.Interfaces.Accounting.IAccountingService
    {
        private readonly DbContext _dbContext;

        public AccountingService(DbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<JournalEntry> CreateJournalEntryAsync(
            string reference,
            string description,
            string createdBy,
            bool isClosed = false,
            params (Guid AccountId, decimal Debit, decimal Credit)[] lines)
        {
            var totalDebit = lines.Sum(l => l.Debit);
            var totalCredit = lines.Sum(l => l.Credit);

            if (Math.Abs(totalDebit - totalCredit) > 0.01m)
                throw new InvalidOperationException($"القيد غير متوازن. مدين: {totalDebit}, دائن: {totalCredit}");

            if (totalDebit == 0)
                throw new InvalidOperationException("لا يمكن إنشاء قيد بقيمة صفر.");

            var journalEntry = new JournalEntry
            {
                VoucherNumber = $"JV-{DateTime.UtcNow:yyyyMMdd}-{Random.Shared.Next(1000, 9999)}",
                Reference = reference,
                Description = description,
                CreatedBy = createdBy,
                IsClosed = isClosed,
                Date = DateTime.UtcNow
            };

            foreach (var line in lines)
            {
                journalEntry.Lines.Add(new JournalEntryLine
                {
                    AccountId = line.AccountId,
                    Debit = line.Debit,
                    Credit = line.Credit,
                    Description = description
                });
            }

            _dbContext.Set<JournalEntry>().Add(journalEntry);
            await _dbContext.SaveChangesAsync();

            return journalEntry;
        }

        public async Task RecordCashSaleAsync(Invoice invoice, string createdBy, decimal cashAmount = 0, decimal visaAmount = 0)
        {
            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var bankAccountId = await GetSystemAccountIdAsync("BANK");
            var visaAccountId = await GetSystemAccountIdAsync("VISA");
            var salesAccountId = await GetSystemAccountIdAsync("SALES");
            var cogsAccountId = await GetSystemAccountIdAsync("COGS");
            var inventoryAccountId = await GetSystemAccountIdAsync("INVENTORY");

            // Determine target account based on PaymentType
            var targetAccountId = cashAccountId;
            string paymentDesc = "نقدية";
            if (invoice.PaymentType == PaymentType.BankTransfer)
            {
                targetAccountId = bankAccountId;
                paymentDesc = "تحويل بنكي";
            }
            else if (invoice.PaymentType == PaymentType.Visa || invoice.PaymentType == PaymentType.Card)
            {
                targetAccountId = visaAccountId;
                paymentDesc = "فيزا";
            }

            // -- Split Payment Support --
            bool isSplitPayment = cashAmount > 0 && visaAmount > 0;
            
            if (isSplitPayment)
            {
                // Create Journal Entry for Split Payment
                var journal = await CreateJournalEntryAsync(
                    reference: invoice.InvoiceNo,
                    description: $"مبيعات مقسمة (نقدي وفيزا) - فاتورة {invoice.InvoiceNo}",
                    createdBy: createdBy,
                    false,
                    (cashAccountId, Debit: cashAmount, Credit: 0),
                    (visaAccountId, Debit: visaAmount, Credit: 0),
                    (salesAccountId, Debit: 0, Credit: invoice.TotalAmount)
                );

                // Cash transaction for Cash part
                _dbContext.Set<CashTransaction>().Add(new CashTransaction
                {
                    Amount = cashAmount,
                    Type = TransactionType.CashIn,
                    ReceiptNumber = invoice.InvoiceNo,
                    Description = $"مبيعات مقسمة (نقدي) - فاتورة {invoice.InvoiceNo}",
                    TargetAccountId = salesAccountId,
                    JournalEntryId = journal.Id,
                    CreatedBy = createdBy,
                    Date = DateTime.UtcNow
                });

                // Cash transaction for Visa part
                _dbContext.Set<CashTransaction>().Add(new CashTransaction
                {
                    Amount = visaAmount,
                    Type = TransactionType.CashIn,
                    ReceiptNumber = invoice.InvoiceNo,
                    Description = $"مبيعات مقسمة (فيزا) - فاتورة {invoice.InvoiceNo}",
                    TargetAccountId = salesAccountId,
                    JournalEntryId = journal.Id,
                    CreatedBy = createdBy,
                    Date = DateTime.UtcNow
                });
            }
            else if (invoice.PaymentType == PaymentType.Installment && invoice.RemainingAmount > 0)
            {
                var arAccountId = await GetSystemAccountIdAsync("ACCOUNTS_RECEIVABLE");

                // 1. Full revenue: Debit Target Account (paid in cash/visa) + Debit AR (remaining) / Credit Sales (total)
                // If down payment is made, where did it go? Assuming cash by default unless specified by visaAmount
                var downPaymentAccount = visaAmount > 0 ? visaAccountId : cashAccountId; 

                var journal = await CreateJournalEntryAsync(
                    reference: invoice.InvoiceNo,
                    description: $"مبيعات بالتقسيط - فاتورة {invoice.InvoiceNo}",
                    createdBy: createdBy,
                    false,
                    (downPaymentAccount, Debit: invoice.PaidAmount, Credit: 0),
                    (arAccountId, Debit: invoice.RemainingAmount, Credit: 0),
                    (salesAccountId, Debit: 0, Credit: invoice.TotalAmount)
                );

                // 2. Cash drawer entry for the down payment
                if (invoice.PaidAmount > 0)
                {
                    _dbContext.Set<CashTransaction>().Add(new CashTransaction
                    {
                        Amount = invoice.PaidAmount,
                        Type = TransactionType.CashIn,
                        ReceiptNumber = invoice.InvoiceNo,
                        Description = $"مقدم أقساط - فاتورة {invoice.InvoiceNo}",
                        TargetAccountId = salesAccountId,
                        JournalEntryId = journal.Id,
                        CreatedBy = createdBy,
                        Date = DateTime.UtcNow
                    });
                }
            }
            else
            {
                // Fallback for single payment type if amounts not specifically provided as split
                decimal actualPaidAmount = invoice.TotalAmount;
                // Cash/Visa/Bank sale: full amount hits target account
                var journal = await CreateJournalEntryAsync(
                    reference: invoice.InvoiceNo,
                    description: $"مبيعات {paymentDesc} - فاتورة {invoice.InvoiceNo}",
                    createdBy: createdBy,
                    false,
                    (targetAccountId, Debit: actualPaidAmount, Credit: 0),
                    (salesAccountId, Debit: 0, Credit: actualPaidAmount)
                );

                if (actualPaidAmount > 0)
                {
                    _dbContext.Set<CashTransaction>().Add(new CashTransaction
                    {
                        Amount = actualPaidAmount,
                        Type = TransactionType.CashIn,
                        ReceiptNumber = invoice.InvoiceNo,
                        Description = $"مبيعات {paymentDesc} - فاتورة {invoice.InvoiceNo}",
                        TargetAccountId = salesAccountId,
                        JournalEntryId = journal.Id,
                        CreatedBy = createdBy,
                        Date = DateTime.UtcNow
                    });
                }
            }

            // 3. COGS entry (unchanged — always records actual cost)
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
                    reference: invoice.InvoiceNo,
                    description: $"إثبات تكلفة البضاعة المباعة لفاتورة {invoice.InvoiceNo}",
                    createdBy: createdBy,
                    false,
                    (cogsAccountId, Debit: actualCost, Credit: 0),
                    (inventoryAccountId, Debit: 0, Credit: actualCost)
                );
            }
        }

        public async Task RecordPurchaseInvoiceAsync(PurchaseInvoice invoice, string createdBy)
        {
            var inventoryAccountId = await GetSystemAccountIdAsync("INVENTORY");
            var supplierControlAccountId = await GetSystemAccountIdAsync("SUPPLIERS_CONTROL");

            var supplier = await _dbContext.Set<Supplier>().FindAsync(invoice.SupplierId);
            var supplierName = supplier?.Name ?? "مورد غير معروف";

            // إثبات قيمة المشتريات (من ح/ المخزون إلى ح/ الموردين)
            // Inventory increases (Debit), Supplier Debt increases (Credit)
            if (invoice.NetAmount > 0)
            {
                await CreateJournalEntryAsync(
                    reference: invoice.InvoiceNo ?? $"PI-{invoice.Id.ToString()[..8]}",
                    description: $"فاتورة مشتريات من المورد: {supplierName}",
                    createdBy: createdBy,
                    false,
                    (inventoryAccountId, Debit: invoice.NetAmount, Credit: 0),
                    (supplierControlAccountId, Debit: 0, Credit: invoice.NetAmount)
                );
            }
        }

        public async Task RecordSupplierPaymentAsync(Guid supplierId, decimal amount, string receiptNo, string createdBy)
        {
            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var supplierControlAccountId = await GetSystemAccountIdAsync("SUPPLIERS_CONTROL");

            var supplier = await _dbContext.Set<Supplier>().FindAsync(supplierId);
            if (supplier == null) throw new Exception("المورد غير موجود.");

            var journal = await CreateJournalEntryAsync(
                reference: receiptNo,
                description: $"دفعة نقدية للمورد {supplier.Name}",
                createdBy: createdBy,
                false,
                (supplierControlAccountId, Debit: amount, Credit: 0),
                (cashAccountId, Debit: 0, Credit: amount)
            );

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount = amount,
                Type = TransactionType.CashOut,
                ReceiptNumber = receiptNo,
                Description = $"سداد للمورد {supplier.Name}",
                TargetAccountId = supplierControlAccountId,
                JournalEntryId = journal.Id,
                CreatedBy = createdBy
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordExpenseAsync(Expense expense, string createdBy)
        {
            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var expensesAccountId = await GetSystemAccountIdAsync("OPERATING_EXPENSES");

            var journal = await CreateJournalEntryAsync(
                reference: $"EXP-{DateTime.UtcNow:yyyyMMdd}-{expense.Id}",
                description: expense.Description ?? "مصروف",
                createdBy: createdBy,
                false,
                (expensesAccountId, Debit: expense.Amount, Credit: 0),
                (cashAccountId, Debit: 0, Credit: expense.Amount)
            );

            expense.JournalEntryId = journal.Id;
            _dbContext.Set<Expense>().Add(expense);

            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount = expense.Amount,
                Type = TransactionType.CashOut,
                ReceiptNumber = $"REC-{DateTime.UtcNow:yyyyMMdd}-{expense.Id}",
                Description = expense.Description,
                TargetAccountId = expensesAccountId,
                JournalEntryId = journal.Id,
                CreatedBy = createdBy
            });

            await _dbContext.SaveChangesAsync();
        }

        public async Task RecordStockAdjustmentAsync(StockAdjustment adjustment, string createdBy)
        {
            var inventoryAccountId = await GetSystemAccountIdAsync("INVENTORY");
            var spoilageAccountId = await GetSystemAccountIdAsync("SPOILAGE_EXPENSES");

            if (adjustment.Cost > 0)
            {
                await CreateJournalEntryAsync(
                    reference: $"ADJ-{adjustment.Id.ToString()[..8]}",
                    description: $"تسوية عجز/تلف مخزون: {adjustment.Reason}",
                    createdBy: createdBy,
                    false,
                    (spoilageAccountId, Debit: adjustment.Cost, Credit: 0),
                    (inventoryAccountId, Debit: 0, Credit: adjustment.Cost)
                );
            }
        }

        // BUG-03: عكس قيد المبيعات عند الإرجاع
        public async Task RecordSalesReturnAsync(ReturnInvoice returnInvoice, string createdBy)
        {
            if (returnInvoice.RefundAmount <= 0) return;

            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var salesAccountId = await GetSystemAccountIdAsync("SALES");
            var inventoryAccountId = await GetSystemAccountIdAsync("INVENTORY");
            var cogsAccountId = await GetSystemAccountIdAsync("COGS");

            // 1. عكس قيد المبيعات (من ح/ المبيعات إلى ح/ الخزينة — مبلغ مسترجع)
            var journal = await CreateJournalEntryAsync(
                reference: returnInvoice.ReturnNo,
                description: $"مرتجع مبيعات - {returnInvoice.ReturnNo}",
                createdBy: createdBy,
                false,
                (salesAccountId, Debit: returnInvoice.RefundAmount, Credit: 0),
                (cashAccountId, Debit: 0, Credit: returnInvoice.RefundAmount)
            );

            // 2. تسجيل الحركة في الخزينة كـ CashOut
            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount = returnInvoice.RefundAmount,
                Type = TransactionType.CashOut,
                ReceiptNumber = returnInvoice.ReturnNo,
                Description = $"استرجاع مبيعات - {returnInvoice.ReturnNo}",
                TargetAccountId = salesAccountId,
                JournalEntryId = journal.Id,
                CreatedBy = createdBy,
                Date = DateTime.UtcNow
            });

            // 3. عكس قيد التكلفة (من ح/ المخزون إلى ح/ تكلفة البضاعة) — استعادة قيمة المخزون
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
                    reference: returnInvoice.ReturnNo,
                    description: $"استعادة تكلفة مخزون مرتجع - {returnInvoice.ReturnNo}",
                    createdBy: createdBy,
                    false,
                    (inventoryAccountId, Debit: returnedCost, Credit: 0),
                    (cogsAccountId, Debit: 0, Credit: returnedCost)
                );
            }

            await _dbContext.SaveChangesAsync();
        }

        // ── FIX-A: Record installment payment in treasury & accounting ──────
        public async Task RecordInstallmentPaymentAsync(Installment installment, decimal amountPaid, string receiptNo, string createdBy)
        {
            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var arAccountId = await GetSystemAccountIdAsync("ACCOUNTS_RECEIVABLE");

            // Journal: Debit Cash, Credit Accounts Receivable (reduce customer debt)
            var journal = await CreateJournalEntryAsync(
                reference: receiptNo,
                description: $"تحصيل قسط - {receiptNo}",
                createdBy: createdBy,
                false,
                (cashAccountId, Debit: amountPaid, Credit: 0),
                (arAccountId, Debit: 0, Credit: amountPaid)
            );

            // Cash drawer entry
            _dbContext.Set<CashTransaction>().Add(new CashTransaction
            {
                Amount = amountPaid,
                Type = TransactionType.CashIn,
                ReceiptNumber = receiptNo,
                Description = $"تحصيل قسط - {receiptNo}",
                TargetAccountId = arAccountId,
                JournalEntryId = journal.Id,
                CreatedBy = createdBy,
                Date = DateTime.UtcNow
            });

            await _dbContext.SaveChangesAsync();
        }

        // ── Helper: get or auto-create system accounts ─────────────────────────
        // NOTE: In production, these should be pre-seeded via a setup wizard.
        //       This fallback is intentionally kept for development only.
        private async Task<Guid> GetSystemAccountIdAsync(string systemCode)
        {
            var acc = await _dbContext.Set<Account>().FirstOrDefaultAsync(a => a.Code == systemCode);
            if (acc == null)
            {
                acc = new Account
                {
                    Code = systemCode,
                    Name = GetArabicAccountName(systemCode),
                    Type = systemCode switch
                    {
                        "CASH" or "BANK" or "VISA" or "INVENTORY" => AccountType.Asset,
                        "SALES" => AccountType.Revenue,
                        "COGS" or "OPERATING_EXPENSES" or "SPOILAGE_EXPENSES" => AccountType.Expense,
                        _ => AccountType.Liability
                    }
                };
                _dbContext.Set<Account>().Add(acc);
                await _dbContext.SaveChangesAsync();
            }
            return acc.Id;
        }

        private static string GetArabicAccountName(string code) => code switch
        {
            "CASH" => "الخزينة الرئيسية",
            "BANK" => "الحساب البنكي",
            "VISA" => "حساب ماكينة الفيزا",
            "SALES" => "إيرادات المبيعات",
            "COGS" => "تكلفة البضاعة المباعة",
            "INVENTORY" => "المخزون",
            "SUPPLIERS_CONTROL" => "حساب المراقبة - الموردون",
            "ACCOUNTS_RECEIVABLE" => "ذمم العملاء المدينة",
            "OPERATING_EXPENSES" => "المصروفات التشغيلية",
            "SPOILAGE_EXPENSES" => "خسائر تأكل المخزون",
            _ => $"حساب نظام - {code}"
        };
    }
}
