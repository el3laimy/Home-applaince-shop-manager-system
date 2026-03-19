using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace ALIkhlasPOS.API.Workers;

public class AutoCloseShiftService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AutoCloseShiftService> _logger;

    public AutoCloseShiftService(IServiceProvider serviceProvider, ILogger<AutoCloseShiftService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("AutoCloseShiftService is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessAutoCloseShiftsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred in AutoCloseShiftService.");
            }

            // Run check every 15 minutes
            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
        }
    }

    private async Task ProcessAutoCloseShiftsAsync(CancellationToken stoppingToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var accountingService = scope.ServiceProvider.GetRequiredService<IAccountingService>();

        var today = DateTime.UtcNow.Date;

        // Find shifts that were opened on previous days and are still open
        var openStaleShifts = await dbContext.Shifts
            .Include(s => s.Cashier)
            .Where(s => s.Status == ShiftStatus.Open && s.StartTime.Date < today)
            .ToListAsync(stoppingToken);

        if (!openStaleShifts.Any()) return;

        foreach (var shift in openStaleShifts)
        {
            try
            {
                var userId = shift.CashierId;
                var cashierUsername = shift.Cashier?.Username ?? "System";

                // 1. Invoices
                var shiftInvoices = await dbContext.Invoices
                    .Where(i => i.CashierId == userId && i.CreatedAt >= shift.StartTime && i.Status == InvoiceStatus.Completed)
                    .ToListAsync(stoppingToken);

                shift.TotalSales = shiftInvoices.Sum(i => i.TotalAmount);
                shift.TotalCashIn = shiftInvoices.Where(i => i.PaymentType == PaymentType.Cash).Sum(i => i.TotalAmount);

                // 2. Installments
                var shiftInstallments = await dbContext.Installments
                    .Include(i => i.Invoice)
                    .Where(i => i.PaidAt != null && i.PaidAt >= shift.StartTime && i.Status == InstallmentStatus.Paid && i.Invoice!.CashierId == userId)
                    .ToListAsync(stoppingToken);

                shift.TotalCashIn += shiftInstallments.Sum(i => i.Amount);

                // 3. Expenses
                var shiftExpenses = await dbContext.Expenses
                    .Where(e => e.Date >= shift.StartTime && e.CreatedBy == cashierUsername)
                    .SumAsync(e => e.Amount, stoppingToken);

                shift.TotalCashOut += shiftExpenses;

                // 4. Return Invoices
                var shiftReturns = await dbContext.ReturnInvoices
                    .Include(r => r.OriginalInvoice)
                    .Where(r => r.CreatedAt >= shift.StartTime && r.OriginalInvoice != null && r.OriginalInvoice.CashierId == userId)
                    .SumAsync(r => r.RefundAmount, stoppingToken);

                shift.TotalCashOut += shiftReturns;

                // 5. Purchases
                var shiftPurchases = await dbContext.PurchaseInvoices
                    .Where(p => p.CreatedAt >= shift.StartTime && p.CreatedBy == cashierUsername)
                    .SumAsync(p => p.PaidAmount, stoppingToken);

                shift.TotalCashOut += shiftPurchases;

                // Final calculations
                shift.ExpectedCash = shift.OpeningCash + shift.TotalCashIn - shift.TotalCashOut;
                
                // Since it's an auto-close, we assume Actual = Expected to avoid false shortages.
                // An audit note is added to indicate it was closed by the system.
                shift.ActualCash = shift.ExpectedCash;
                shift.Difference = 0;

                shift.EndTime = DateTime.UtcNow;
                shift.Status = ShiftStatus.Closed;
                shift.Notes = "تم الإقفال التلقائي بواسطة النظام لتجاوز يوم العمل.";

                await dbContext.SaveChangesAsync(stoppingToken);
                await accountingService.RecordShiftClosureAsync(shift, "System");

                _logger.LogInformation("Auto-closed shift {ShiftId} for cashier {Cashier}", shift.Id, cashierUsername);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to auto-close shift {ShiftId}", shift.Id);
            }
        }
    }
}
