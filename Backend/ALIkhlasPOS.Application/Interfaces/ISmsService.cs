using System.Threading;
using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces
{
    /// <summary>
    /// واجهة إرسال الرسائل القصيرة — قابلة للتوصيل بأي مزود (VictoryLink, Twilio, Unifonic...)
    /// يتم اختيار المزود ديناميكياً من إعدادات المتجر دون الحاجة لإعادة تجميع الكود.
    /// </summary>
    public interface ISmsService
    {
        /// <summary>
        /// يرسل رسالة SMS ويعيد true إذا نجح، false إذا فشل.
        /// </summary>
        /// <param name="toPhoneNumber">رقم الهاتف الدولي (مثلاً +201012345678)</param>
        /// <param name="message">نص الرسالة</param>
        /// <param name="cancellationToken">معرّف الإلغاء</param>
        Task<(bool Success, string? ErrorMessage)> SendAsync(
            string toPhoneNumber,
            string message,
            CancellationToken cancellationToken = default);
    }
}
