using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces;

public interface IInstallmentService
{
    Task<InstallmentScheduleResponse> GenerateScheduleAsync(GenerateScheduleDto request, CancellationToken cancellationToken);
    
    Task<InstallmentPaymentResponse> PayInstallmentAsync(Guid installmentId, decimal amountPaid, string createdBy, CancellationToken cancellationToken);
    
    Task<InstallmentReminderResponse> SendReminderAsync(Guid installmentId, CancellationToken cancellationToken);
    
    Task<TestSmsResponse> TestSmsAsync(TestSmsDto request, CancellationToken cancellationToken);
}

// DTOs
public record GenerateScheduleDto(Guid InvoiceId, Guid CustomerId, decimal DownPayment, int NumberOfMonths, DateTime FirstInstallmentDate);
public record TestSmsDto(string Phone, string Provider, string ApiKey, string SenderId);

// Responses
public record InstallmentScheduleResponse(bool Success, string Message, int InstallmentsCount);
public record InstallmentPaymentResponse(bool Success, string Message, string? Status, DateTime? PaidAt);
public record InstallmentReminderResponse(bool Success, string Message, string? Phone, DateTime? DueDate, decimal? Amount);
public record TestSmsResponse(bool Success, string Message);
