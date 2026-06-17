using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;

namespace ALIkhlasPOS.Infrastructure.Sms
{
    /// <summary>
    /// تنفيذ SMS عبر VictoryLink (مصر) أو Unifonic أو أي مزود يدعم HTTP API مشابه.
    ///
    /// إعدادات مطلوبة في لوحة الإعدادات:
    ///   SmsProvider  = VictoryLink
    ///   SmsApiKey    = username:password (مفصولة بنقطتين)
    ///   SmsSenderId  = اسم المرسل (Sender ID مسجّل عند المزود)
    ///
    /// API endpoint: https://smsvas.com/bulk/public/index.php/api/v1/sendscheduledmessage
    /// </summary>
    public class VictoryLinkSmsService : ISmsService
    {
        private readonly IHttpClientFactory _httpFactory;
        private readonly string _username;
        private readonly string _password;
        private readonly string _senderId;

        public VictoryLinkSmsService(IHttpClientFactory httpFactory, string usernameColonPassword, string senderId)
        {
            _httpFactory = httpFactory;
            var parts = usernameColonPassword.Split(':', 2);
            _username = parts.Length > 0 ? parts[0] : usernameColonPassword;
            _password = parts.Length > 1 ? parts[1] : "";
            _senderId = senderId;
        }

        public async Task<(bool Success, string? ErrorMessage)> SendAsync(
            string toPhoneNumber, string message, CancellationToken cancellationToken = default)
        {
            try
            {
                var client = _httpFactory.CreateClient("SmsClient");
                var payload = new
                {
                    UserName = _username,
                    Password = _password,
                    SMSSender = _senderId,
                    SMSLang = "A",   // A = Arabic, E = English
                    SMSReceiver = NormalizeEgyptNumber(toPhoneNumber),
                    SMSText = message
                };

                var response = await client.PostAsJsonAsync(
                    "https://smsvas.com/bulk/public/index.php/api/v1/sendscheduledmessage",
                    payload,
                    cancellationToken);

                var body = await response.Content.ReadAsStringAsync(cancellationToken);

                if (response.IsSuccessStatusCode && body.Contains("SENT", StringComparison.OrdinalIgnoreCase))
                    return (true, null);

                return (false, $"VictoryLink رفض الطلب: {body}");
            }
            catch (Exception ex)
            {
                return (false, $"خطأ في الاتصال بـ VictoryLink: {ex.Message}");
            }
        }

        /// <summary>تحويل الأرقام المصرية 010/011/012/015 إلى الصيغة الدولية 2010....</summary>
        private static string NormalizeEgyptNumber(string phone)
        {
            phone = phone.Trim().Replace(" ", "").Replace("-", "");
            if (phone.StartsWith("0")) phone = "2" + phone.TrimStart('0'); // 010... → 2010...
            if (!phone.StartsWith("+")) phone = "+" + phone;
            return phone;
        }
    }

    /// <summary>
    /// تنفيذ SMS عبر Twilio — يدعم جميع الدول.
    ///
    /// إعدادات مطلوبة في لوحة الإعدادات:
    ///   SmsProvider  = Twilio
    ///   SmsApiKey    = AccountSID:AuthToken  (مفصولة بنقطتين)
    ///   SmsSenderId  = رقم هاتف Twilio بالصيغة الدولية (مثلاً +12025551234)
    /// </summary>
    public class TwilioSmsService : ISmsService
    {
        private readonly IHttpClientFactory _httpFactory;
        private readonly string _accountSid;
        private readonly string _authToken;
        private readonly string _fromNumber;

        public TwilioSmsService(IHttpClientFactory httpFactory, string sidColonToken, string fromNumber)
        {
            _httpFactory = httpFactory;
            var parts = sidColonToken.Split(':', 2);
            _accountSid = parts.Length > 0 ? parts[0] : sidColonToken;
            _authToken  = parts.Length > 1 ? parts[1] : "";
            _fromNumber = fromNumber;
        }

        public async Task<(bool Success, string? ErrorMessage)> SendAsync(
            string toPhoneNumber, string message, CancellationToken cancellationToken = default)
        {
            try
            {
                var client = _httpFactory.CreateClient("SmsClient");

                // Twilio Basic Auth
                var credentials = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{_accountSid}:{_authToken}"));
                client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", credentials);

                var form = new FormUrlEncodedContent([
                    new("To",   toPhoneNumber),
                    new("From", _fromNumber),
                    new("Body", message),
                ]);

                var response = await client.PostAsync(
                    $"https://api.twilio.com/2010-04-01/Accounts/{_accountSid}/Messages.json",
                    form,
                    cancellationToken);

                if (response.IsSuccessStatusCode)
                    return (true, null);

                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                return (false, $"Twilio خطأ: {body}");
            }
            catch (Exception ex)
            {
                return (false, $"خطأ في الاتصال بـ Twilio: {ex.Message}");
            }
        }
    }
}
