using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Workers;

public class InstallmentReminderService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<InstallmentReminderService> _logger;
    private readonly IConfiguration _config;

    public InstallmentReminderService(
        IServiceProvider serviceProvider,
        ILogger<InstallmentReminderService> logger,
        IConfiguration config)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _config = config;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Installment Reminder Service started.");

        // Run immediately on startup then on interval
        await RunAsync(stoppingToken);

        // Configurable interval (default: every 6 hours)
        var intervalHours = _config.GetValue<int>("AppSettings:InstallmentCheckHours", 6);

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromHours(intervalHours), stoppingToken);
            await RunAsync(stoppingToken);
        }
    }

    private async Task RunAsync(CancellationToken ct)
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var today = DateTime.UtcNow.Date;

            // ── 1. Auto-mark overdue installments ────────────────────────────
            var overdueToMark = await db.Installments
                .Where(i => i.Status == InstallmentStatus.Pending && i.DueDate < today)
                .ToListAsync(ct);

            foreach (var inst in overdueToMark)
                inst.Status = InstallmentStatus.Overdue;

            if (overdueToMark.Any())
            {
                await db.SaveChangesAsync(ct);
                _logger.LogWarning("Auto-marked {Count} installments as Overdue.", overdueToMark.Count);
            }

            // ── 2. Send reminders for installments due in the next 3 days ───
            var upcoming = today.AddDays(3);
            var dueInstallments = await db.Installments
                .Include(i => i.Invoice).ThenInclude(inv => inv!.Customer)
                .Where(i => i.Status == InstallmentStatus.Overdue
                         || (i.Status == InstallmentStatus.Pending
                             && !i.ReminderSent
                             && i.DueDate <= upcoming))
                .ToListAsync(ct);

            var shopSettings = await db.ShopSettings.FirstOrDefaultAsync(ct);
            var smsConfigured = !string.IsNullOrEmpty(shopSettings?.SmsApiKey);
            var reminderCount = 0;

            foreach (var inst in dueInstallments)
            {
                if (inst.ReminderSent) continue;

                var customerName = inst.Invoice?.Customer?.Name ?? "عميل";
                var phone = inst.Invoice?.Customer?.Phone;

                if (smsConfigured && !string.IsNullOrEmpty(phone))
                {
                    // Real SMS: call shopSettings.SmsApiKey provider here
                    // e.g. await _smsProvider.SendAsync(phone, $"تذكير: قسطك {inst.Amount} ج.م يستحق {inst.DueDate:yyyy-MM-dd}");
                    _logger.LogInformation(
                        "[SMS-READY] Would send to {Phone} for customer '{Customer}': Amount={Amount} Due={Due}",
                        phone, customerName, inst.Amount, inst.DueDate.ToString("yyyy-MM-dd"));
                }
                else
                {
                    _logger.LogInformation(
                        "[REMINDER-LOG] Customer '{Customer}' | Amount: {Amount} | Due: {Due}",
                        customerName, inst.Amount, inst.DueDate.ToString("yyyy-MM-dd"));
                }

                inst.ReminderSent = true;
                reminderCount++;
            }

            if (reminderCount > 0)
                await db.SaveChangesAsync(ct);

            _logger.LogInformation(
                "Reminder cycle complete: {Reminders} reminders sent, {Overdue} auto-marked overdue. SMS={SmsConfigured}",
                reminderCount, overdueToMark.Count, smsConfigured);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during installment reminder cycle.");
        }
    }
}
