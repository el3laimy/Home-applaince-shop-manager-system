using System;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace ALIkhlasPOS.Infrastructure.Services;

/// <summary>
/// تنفيذ ISystemAccountService — يسترد أو ينشئ حساباً نظامياً بكوده المختصر.
/// يوفر حماية من Race Conditions عبر معالجة DbUpdateException إضافة للتخزين المؤقت لمعالجة أسرع.
/// </summary>
public class SystemAccountService : ISystemAccountService
{
    private readonly ApplicationDbContext _db;
    private readonly IMemoryCache _cache;

    public SystemAccountService(ApplicationDbContext db, IMemoryCache cache)
    {
        _db = db;
        _cache = cache;
    }

    public async Task<Guid> GetSystemAccountIdAsync(string systemCode)
    {
        var cacheKey = $"SystemAccount_{systemCode}";

        if (_cache.TryGetValue<Guid>(cacheKey, out var cachedId))
        {
            return cachedId;
        }

        var acc = await _db.Set<Account>()
            .AsNoTracking()
            .FirstOrDefaultAsync(a => a.Code == systemCode);

        if (acc != null)
        {
            _cache.Set(cacheKey, acc.Id, TimeSpan.FromHours(24));
            return acc.Id;
        }

        // الحساب غير موجود — أنشئه مع الحماية من التزامن
        acc = new Account
        {
            Code = systemCode,
            Name = GetArabicAccountName(systemCode),
            Type = systemCode switch
            {
                "CASH" or "BANK" or "VISA" or "INVENTORY"
                    or "ACCOUNTS_RECEIVABLE" or "MAIN_TREASURY" => AccountType.Asset,
                "SALES" or "OTHER_REVENUES"                     => AccountType.Revenue,
                "COGS" or "OPERATING_EXPENSES"
                    or "SPOILAGE_EXPENSES"                      => AccountType.Expense,
                "EQUITY_CAPITAL"                               => AccountType.Equity,
                _                                              => AccountType.Liability
            },
            IsActive = true
        };

        _db.Set<Account>().Add(acc);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            // حالة تزامن: خيط آخر أنشأ الحساب — أعد الجلب
            _db.Entry(acc).State = EntityState.Detached;
            acc = await _db.Set<Account>()
                .AsNoTracking()
                .FirstAsync(a => a.Code == systemCode);
        }

        _cache.Set(cacheKey, acc.Id, TimeSpan.FromHours(24));
        return acc.Id;
    }

    private static string GetArabicAccountName(string code) => code switch
    {
        "CASH"               => "الخزينة الرئيسية",
        "BANK"               => "الحساب البنكي",
        "VISA"               => "حساب ماكينة الفيزا",
        "MAIN_TREASURY"      => "الخزينة الرئيسية (التحويل)",
        "SALES"              => "إيرادات المبيعات",
        "OTHER_REVENUES"     => "إيرادات أخرى",
        "COGS"               => "تكلفة البضاعة المباعة",
        "INVENTORY"          => "المخزون",
        "ACCOUNTS_RECEIVABLE"=> "ذمم العملاء المدينة",
        "SUPPLIERS_CONTROL"  => "حساب المراقبة - الموردون",
        "OPERATING_EXPENSES" => "المصروفات التشغيلية",
        "SPOILAGE_EXPENSES"  => "خسائر تأكل المخزون",
        "EQUITY_CAPITAL"     => "رأس المال",
        _                    => $"حساب نظام - {code}"
    };
}
