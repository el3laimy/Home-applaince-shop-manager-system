using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces;

/// <summary>
/// خدمة موحدة لاسترداد Guid الحسابات النظامية بالكود المختصر (مثال: "CASH", "SALES").
/// تُستخدم في AccountingService وجميع الـ Controllers التي تحتاج الوصول لهذه الحسابات.
/// </summary>
public interface ISystemAccountService
{
    /// <summary>
    /// يعيد Guid الحساب المرتبط بالكود النظامي المعطى.
    /// إذا لم يوجد الحساب، يُنشئه تلقائياً مع الحماية من حالات التزامن (Race Conditions).
    /// </summary>
    /// <param name="systemCode">الكود النظامي الداخلي (مثال: "CASH", "SALES", "COGS")</param>
    Task<Guid> GetSystemAccountIdAsync(string systemCode);
}
