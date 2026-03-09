using System;
using System.ComponentModel.DataAnnotations;

namespace ALIkhlasPOS.Domain.Entities
{
    /// <summary>
    /// Shop profile settings — used in receipt printing, reports headers.
    /// Singleton table: always 1 row.
    /// </summary>
    public class ShopSettings
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        [StringLength(200)]
        public string ShopName { get; set; } = string.Empty; // اسم المحل

        [StringLength(500)]
        public string? Address { get; set; } // العنوان

        [StringLength(20)]
        public string? Phone { get; set; } // رقم الهاتف

        [StringLength(20)]
        public string? Phone2 { get; set; } // رقم هاتف بديل

        [StringLength(50)]
        public string? CommercialRegNo { get; set; } // رقم السجل التجاري

        [StringLength(50)]
        public string? TaxNumber { get; set; } // الرقم الضريبي

        public string? LogoBase64 { get; set; } // شعار المحل (Base64 encoded)

        [StringLength(500)]
        public string? ReceiptFooter { get; set; } // تذييل الإيصال (مثلاً: "شكراً لزيارتكم")

        // VAT settings
        public bool VatEnabled { get; set; } = false;
        public decimal DefaultVatRate { get; set; } = 14; // 14% in Egypt

        // Currency settings
        [StringLength(10)]
        public string CurrencySymbol { get; set; } = "ج.م"; // جنيه مصري

        [StringLength(10)]
        public string CurrencyCode { get; set; } = "EGP";

        // SMS notifications (optional — integrate with any SMS provider)
        [StringLength(500)]
        public string? SmsApiKey { get; set; }  // API key / username:password for SMS provider

        [StringLength(100)]
        public string? SmsSenderId { get; set; } // Sender ID shown on SMS

        /// <summary>
        /// BUG-07: اسم مزود SMS.
        /// القيم المقبولة: "VictoryLink" | "Twilio" | "Unifonic"
        /// يتم اختياره من شاشة الإعدادات في التطبيق.
        /// </summary>
        [StringLength(50)]
        public string? SmsProvider { get; set; }

        [StringLength(500)]
        public string? BackupPath { get; set; }

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
