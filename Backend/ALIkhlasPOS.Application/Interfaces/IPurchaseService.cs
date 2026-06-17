using System;
using System.Threading;
using System.Threading.Tasks;

namespace ALIkhlasPOS.Application.Interfaces;

public interface IPurchaseService
{
    /// <summary>
    /// Creates a new purchase invoice (Draft or Completed).
    /// </summary>
    Task<PurchaseCreateResponse> CreatePurchaseInvoiceAsync(
        PurchaseCreateDto dto,
        string createdBy,
        CancellationToken cancellationToken);

    /// <summary>
    /// Promotes a Draft purchase invoice to Completed, applying stock and accounting entries.
    /// </summary>
    Task<PurchaseApproveResponse> ApproveDraftAsync(
        Guid invoiceId,
        string createdBy,
        CancellationToken cancellationToken);
}

/// <summary>Response returned after creating a purchase invoice.</summary>
public record PurchaseCreateResponse(Guid Id, string? InvoiceNo, decimal NetAmount, decimal RemainingAmount);

/// <summary>Response returned after approving a draft purchase invoice.</summary>
public record PurchaseApproveResponse(string Message, Guid Id, string Status);
