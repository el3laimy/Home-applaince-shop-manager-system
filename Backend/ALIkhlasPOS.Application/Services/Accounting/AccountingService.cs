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

        public async Task RecordCashSaleAsync(Invoice invoice, string createdBy)
        {
            var cashAccountId = await GetSystemAccountIdAsync("CASH");
            var salesAccountId = await GetSystemAccountIdAsync("SALES");
            var cogsAccountId = await GetSystemAccountIdAsync("COGS");
            var inventoryAccountId = await GetSystemAccountIdAsync("INVENTORY");

            // 1. قيد المبيعات (من ح/ الخزينة إلى ح/ إيرادات المبيعات)
            await CreateJournalEntryAsync(
                reference: invoice.InvoiceNo,
                description: $"مبيعات ناتجة عن فاتورة {invoice.InvoiceNo}",
                createdBy: createdBy,
                (cashAccountId, Debit: invoice.TotalAmount, Credit: 0),
                (salesAccountId, Debit: 0, Credit: invoice.TotalAmount)
            );

            // 2. قيد التكلفة (من ح/ تكلفة البضاعة المباعة إلى ح/ المخزون)
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
                    (cogsAccountId, Debit: actualCost, Credit: 0),
                    (inventoryAccountId, Debit: 0, Credit: actualCost)
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
                        "CASH" or "INVENTORY" => AccountType.Asset,
                        "SALES" => AccountType.Revenue,
                        "COGS" or "OPERATING_EXPENSES" => AccountType.Expense,
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
            "SALES" => "إيرادات المبيعات",
            "COGS" => "تكلفة البضاعة المباعة",
            "INVENTORY" => "المخزون",
            "SUPPLIERS_CONTROL" => "حساب المراقبة - الموردون",
            "OPERATING_EXPENSES" => "المصروفات التشغيلية",
            _ => $"حساب نظام - {code}"
        };
    }
}
