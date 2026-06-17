using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.Application.Interfaces;

public interface IReturnInvoiceService
{
    /// <summary>
    /// Validates and processes a product return against an original invoice.
    /// Restores stock atomically, records accounting entries, and invalidates
    /// Redis cache only after a successful transaction commit.
    /// </summary>
    Task<ReturnInvoiceResponse> ProcessReturnAsync(
        ReturnInvoiceCreateDto dto,
        string createdBy,
        CancellationToken cancellationToken);
}

// ── Application-layer DTOs (decoupled from HTTP layer) ─────────────────────────

public record ReturnInvoiceItemDto(
    Guid ProductId,
    decimal Quantity,
    Guid? ParentBundleId = null,
    decimal? CustomUnitPrice = null
);

public record ReturnInvoiceCreateDto(
    Guid OriginalInvoiceId,
    ReturnReason Reason,
    string? Notes,
    List<ReturnInvoiceItemDto> Items
);

public record ReturnInvoiceResponse(
    Guid Id,
    string ReturnNo,
    decimal RefundAmount,
    string Message
);
