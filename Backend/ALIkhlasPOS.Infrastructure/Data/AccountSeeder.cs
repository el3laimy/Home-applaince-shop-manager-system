using System;
using System.Linq;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace ALIkhlasPOS.Infrastructure.Data
{
    public static class AccountSeeder
    {
        public static async Task SeedChartOfAccountsAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

            // Fast exit if we already have accounts
            if (await dbContext.Accounts.AnyAsync()) return;

            // 1. Level 1: Main account groups
            var assets = CreateAccount("1", "الأصول", AccountType.Asset, null);
            var liabilities = CreateAccount("2", "الخصوم", AccountType.Liability, null);
            var equity = CreateAccount("3", "حقوق الملكية", AccountType.Equity, null);
            var revenues = CreateAccount("4", "الإيرادات", AccountType.Revenue, null);
            var expenses = CreateAccount("5", "المصروفات", AccountType.Expense, null);

            dbContext.Accounts.AddRange(assets, liabilities, equity, revenues, expenses);
            await dbContext.SaveChangesAsync();

            // 2. Level 2: Assets Sub-groups
            var currentAssets = CreateAccount("11", "الأصول المتداولة", AccountType.Asset, assets.Id);
            var fixedAssets = CreateAccount("12", "الأصول الثابتة", AccountType.Asset, assets.Id);
            dbContext.Accounts.AddRange(currentAssets, fixedAssets);

            // 3. Level 2: Liabilities Sub-groups
            var currentLiabilities = CreateAccount("21", "الخصوم المتداولة", AccountType.Liability, liabilities.Id);
            var longTermLiabilities = CreateAccount("22", "خصوم طويلة الأجل", AccountType.Liability, liabilities.Id);
            dbContext.Accounts.AddRange(currentLiabilities, longTermLiabilities);

            // 4. Level 2: Equity & Revenues & Expenses Sub-groups
            var capital = CreateAccount("31", "رأس المال", AccountType.Equity, equity.Id);
            var retainedEarnings = CreateAccount("32", "الأرباح المحتجزة", AccountType.Equity, equity.Id);
            
            var operatingRevenues = CreateAccount("41", "إيرادات التشغيل", AccountType.Revenue, revenues.Id);
            var otherRevenues = CreateAccount("42", "إيرادات أخرى", AccountType.Revenue, revenues.Id);
            
            var costOfGoodsSold = CreateAccount("51", "تكلفة البضاعة المباعة (COGS)", AccountType.Expense, expenses.Id);
            var operatingExpenses = CreateAccount("52", "المصروفات التشغيلية", AccountType.Expense, expenses.Id);
            
            dbContext.Accounts.AddRange(capital, retainedEarnings, operatingRevenues, otherRevenues, costOfGoodsSold, operatingExpenses);
            await dbContext.SaveChangesAsync();

            // 5. Level 3: Detailed Ledger Accounts (Mapped to System Codes used by AccountingService)
            var cash = CreateAccount("1101", "الخزينة الرئيسية", AccountType.Asset, currentAssets.Id, "CASH");
            var bank = CreateAccount("1102", "الحسابات البنكية", AccountType.Asset, currentAssets.Id, "BANK");
            var visa = CreateAccount("1103", "حساب الفيزا (POS)", AccountType.Asset, currentAssets.Id, "VISA");
            var accountsReceivable = CreateAccount("1104", "ذمم العملاء (مدينون)", AccountType.Asset, currentAssets.Id, "ACCOUNTS_RECEIVABLE");
            var inventory = CreateAccount("1105", "المخزون", AccountType.Asset, currentAssets.Id, "INVENTORY");

            var suppliersControl = CreateAccount("2101", "حساب المراقبة - الموردون (دائنون)", AccountType.Liability, currentLiabilities.Id, "SUPPLIERS_CONTROL");
            var vatPayable = CreateAccount("2102", "الضرائب المستحقة (ضريبة القيمة المضافة)", AccountType.Liability, currentLiabilities.Id, "VAT_PAYABLE");

            var sales = CreateAccount("4101", "إيرادات المبيعات", AccountType.Revenue, operatingRevenues.Id, "SALES");
            
            var cogsBasic = CreateAccount("5101", "تكلفة مبيعات البضاعة", AccountType.Expense, costOfGoodsSold.Id, "COGS");
            var spoilage = CreateAccount("5102", "خسائر تالف أو عجز المخزون", AccountType.Expense, costOfGoodsSold.Id, "SPOILAGE_EXPENSES");
            var generalExpenses = CreateAccount("5201", "مصروفات عمومية وإدارية", AccountType.Expense, operatingExpenses.Id, "OPERATING_EXPENSES");

            dbContext.Accounts.AddRange(
                cash, bank, visa, accountsReceivable, inventory,
                suppliersControl, vatPayable,
                sales, cogsBasic, spoilage, generalExpenses
            );

            await dbContext.SaveChangesAsync();
        }

        private static Account CreateAccount(string code, string name, AccountType type, Guid? parentId, string systemCode = null!)
        {
            return new Account
            {
                Code = systemCode ?? code, // Replace Code with SystemCode internally for existing compatibility
                Name = $"{code} - {name}",
                Type = type,
                ParentAccountId = parentId,
                IsActive = true
            };
        }
    }
}
