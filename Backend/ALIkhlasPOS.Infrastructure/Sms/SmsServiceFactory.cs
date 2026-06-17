using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.Infrastructure.Sms
{
    /// <summary>
    /// مصنع يختار تنفيذ ISmsService المناسب بناءً على إعدادات المتجر.
    /// يُستخدم داخل InstallmentsController بدلاً من حقن ISmsService مباشرة،
    /// لأن الإعدادات تتغير بدون إعادة تشغيل الخادم.
    /// </summary>
    public class SmsServiceFactory
    {
        private readonly IHttpClientFactory _httpFactory;

        public SmsServiceFactory(IHttpClientFactory httpFactory)
        {
            _httpFactory = httpFactory;
        }

        /// <summary>
        /// يبني خدمة SMS من إعدادات المتجر الحالية.
        /// يُعيد null إذا لم تكن إعدادات SMS مكتملة.
        /// </summary>
        public ISmsService? Create(ShopSettings settings)
        {
            if (string.IsNullOrWhiteSpace(settings.SmsApiKey) ||
                string.IsNullOrWhiteSpace(settings.SmsSenderId) ||
                string.IsNullOrWhiteSpace(settings.SmsProvider))
                return null;

            return settings.SmsProvider.ToLowerInvariant() switch
            {
                "twilio" => new TwilioSmsService(_httpFactory, settings.SmsApiKey, settings.SmsSenderId),
                "victorylink" or "victory" => new VictoryLinkSmsService(_httpFactory, settings.SmsApiKey, settings.SmsSenderId),
                "unifonic" => new UnifonicSmsService(_httpFactory, settings.SmsApiKey, settings.SmsSenderId),
                _ => null  // مزود غير معروف
            };
        }
    }

    /// <summary>
    /// Unifonic SMS — مزود سعودي/خليجي يدعم مصر.
    /// SmsApiKey = AppSid (من لوحة Unifonic)
    /// SmsSenderId = SenderID المسجّل
    /// </summary>
    public class UnifonicSmsService : ISmsService
    {
        private readonly IHttpClientFactory _httpFactory;
        private readonly string _appSid;
        private readonly string _senderId;

        public UnifonicSmsService(IHttpClientFactory httpFactory, string appSid, string senderId)
        {
            _httpFactory = httpFactory;
            _appSid = appSid;
            _senderId = senderId;
        }

        public async Task<(bool Success, string? ErrorMessage)> SendAsync(
            string toPhoneNumber, string message, CancellationToken cancellationToken = default)
        {
            try
            {
                var client = _httpFactory.CreateClient("SmsClient");
                var form = new FormUrlEncodedContent([
                    new("AppSid",    _appSid),
                    new("SenderID",  _senderId),
                    new("Recipient", toPhoneNumber.TrimStart('+')),
                    new("Body",      message),
                ]);

                var response = await client.PostAsync(
                    "https://api.unifonic.com/rest/Messages/Send",
                    form, cancellationToken);

                return response.IsSuccessStatusCode
                    ? (true, null)
                    : (false, $"Unifonic HTTP {response.StatusCode}");
            }
            catch (System.Exception ex)
            {
                return (false, ex.Message);
            }
        }
    }
}
