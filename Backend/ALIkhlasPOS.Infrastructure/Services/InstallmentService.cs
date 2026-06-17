using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Infrastructure.Sms;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Infrastructure.Services;

public class InstallmentService : IInstallmentService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly SmsServiceFactory _smsFactory;
    private readonly IAccountingService _accountingService;

    public InstallmentService(ApplicationDbContext dbContext, SmsServiceFactory smsFactory, IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _smsFactory = smsFactory;
        _accountingService = accountingService;
    }

    public async Task<InstallmentScheduleResponse> GenerateScheduleAsync(GenerateScheduleDto request, CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Invoices.FindAsync(new object[] { request.InvoiceId }, cancellationToken);
        if (invoice == null) return new InstallmentScheduleResponse(false, "Invoice not found", 0);
        if (invoice.PaymentType != PaymentType.Installment) 
            return new InstallmentScheduleResponse(false, "Invoice is not marked for installments.", 0);

        var remainingAmount = invoice.TotalAmount - request.DownPayment;
        if (remainingAmount <= 0) 
            return new InstallmentScheduleResponse(false, "Down payment covers the entire invoice amount.", 0);

        decimal monthlyAmount = Math.Round(remainingAmount / request.NumberOfMonths, 2);
        var installments = new List<Installment>();
        
        for (int i = 0; i < request.NumberOfMonths; i++)
        {
            decimal currentAmount = (i == request.NumberOfMonths - 1)
                ? remainingAmount - (monthlyAmount * (request.NumberOfMonths - 1))
                : monthlyAmount;
            
            installments.Add(new Installment
            {
                InvoiceId = invoice.Id,
                CustomerId = request.CustomerId,
                Amount = currentAmount,
                DueDate = request.FirstInstallmentDate.AddMonths(i).ToUniversalTime(),
                Status = InstallmentStatus.Pending,
                ReminderSent = false
            });
        }
        
        _dbContext.Installments.AddRange(installments);
        await _dbContext.SaveChangesAsync(cancellationToken);
        
        return new InstallmentScheduleResponse(true, "تم إنشاء جدول الأقساط.", installments.Count);
    }

    public async Task<InstallmentPaymentResponse> PayInstallmentAsync(Guid installmentId, decimal amountPaid, string createdBy, CancellationToken cancellationToken)
    {
        var installment = await _dbContext.Installments
            .Include(i => i.Invoice)
            .FirstOrDefaultAsync(i => i.Id == installmentId, cancellationToken);

        if (installment == null) return new InstallmentPaymentResponse(false, "Installment not found", null, null);
        if (installment.Status == InstallmentStatus.Paid)
            return new InstallmentPaymentResponse(false, "هذا القسط مدفوع بالفعل.", null, null);

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            installment.Status = InstallmentStatus.Paid;
            installment.PaidAt = DateTime.UtcNow;

            if (installment.Invoice != null)
            {
                installment.Invoice.PaidAmount += amountPaid;
                installment.Invoice.RemainingAmount = Math.Max(0, installment.Invoice.TotalAmount - installment.Invoice.PaidAmount);
                if (installment.Invoice.RemainingAmount == 0)
                    installment.Invoice.Status = InvoiceStatus.Completed;
            }

            var customer = await _dbContext.Customers.FindAsync(new object[] { installment.CustomerId }, cancellationToken);
            if (customer != null)
            {
                customer.TotalPaid += amountPaid;
            }

            await _dbContext.SaveChangesAsync(cancellationToken);

            var receiptNo = $"INST-{installment.Id.ToString()[..8]}";
            await _accountingService.RecordInstallmentPaymentAsync(installment, amountPaid, receiptNo, createdBy);

            await transaction.CommitAsync(cancellationToken);
            return new InstallmentPaymentResponse(true, "تم تسجيل الدفعة وتحديث الخزينة بنجاح.", installment.Status.ToString(), installment.PaidAt);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return new InstallmentPaymentResponse(false, $"خطأ في تسجيل الدفعة: {ex.Message}", null, null);
        }
    }

    public async Task<InstallmentReminderResponse> SendReminderAsync(Guid installmentId, CancellationToken cancellationToken)
    {
        var installment = await _dbContext.Installments
            .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
            .FirstOrDefaultAsync(i => i.Id == installmentId, cancellationToken);

        if (installment == null) return new InstallmentReminderResponse(false, "Installment not found", null, null, null);

        var phone = installment.Invoice?.Customer?.Phone;
        if (string.IsNullOrEmpty(phone))
            return new InstallmentReminderResponse(false, "العميل ليس له رقم هاتف مسجل.", null, null, null);

        var settings = await _dbContext.Set<ShopSettings>().FirstOrDefaultAsync(cancellationToken);
        var smsService = _smsFactory.Create(settings!);

        if (smsService == null)
        {
            return new InstallmentReminderResponse(false, "لم يتم تهيئة خدمة SMS. يرجى تعيين مزود الرسائل وبيانات الاعتماد في إعدادات المتجر.", null, null, null);
        }

        var customerName = installment.Invoice?.Customer?.Name ?? "العميل الكريم";
        var shopName = settings?.ShopName ?? "المتجر";
        var message = $"عزيزي {customerName}،\n" +
                      $"تذكير بموعد قسط بقيمة {installment.Amount:F2} ج.م" +
                      $" المستحق بتاريخ {installment.DueDate:dd/MM/yyyy}.\n" +
                      $"يرجى السداد في موعده. — {shopName}";

        var (success, error) = await smsService.SendAsync(phone, message, cancellationToken);

        if (!success)
        {
            return new InstallmentReminderResponse(false, $"فشل إرسال الرسالة: {error}", null, null, null);
        }

        installment.ReminderSent = true;
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new InstallmentReminderResponse(true, $"✓ تم إرسال تذكير SMS للعميل {customerName} على الرقم {phone}", phone, installment.DueDate, installment.Amount);
    }

    public async Task<TestSmsResponse> TestSmsAsync(TestSmsDto request, CancellationToken cancellationToken)
    {
        var tempSettings = new ShopSettings
        {
            SmsProvider = request.Provider,
            SmsApiKey = request.ApiKey,
            SmsSenderId = request.SenderId,
            ShopName = "ALIkhlasPOS"
        };

        var smsService = _smsFactory.Create(tempSettings);
        if (smsService == null)
            return new TestSmsResponse(false, "بيانات المزود غير صحيحة أو ناقصة.");

        var testMessage = $"هذه رسالة اختبار من نظام إخلاص كاشير. المزود: {request.Provider}. وقت الإرسال: {DateTime.Now:HH:mm}";
        var (success, error) = await smsService.SendAsync(request.Phone, testMessage, cancellationToken);

        if (success)
            return new TestSmsResponse(true, $"✓ تم إرسال رسالة الاختبار إلى {request.Phone} بنجاح");
        else
            return new TestSmsResponse(false, $"فشل الإرسال: {error}");
    }
}
