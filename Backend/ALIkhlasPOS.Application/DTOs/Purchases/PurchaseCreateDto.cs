using System;
using System.Collections.Generic;

namespace ALIkhlasPOS.Application.Interfaces;

/// <summary>Application-layer DTO for creating a purchase invoice (decoupled from HTTP layer).</summary>
public record PurchaseCreateDto(
    string? InvoiceNo,
    Guid SupplierId,
    decimal Discount,
    decimal PaidAmount,
    string? Notes,
    string Status,
    List<PurchaseItemDto> Items
);

/// <summary>A single line item within a purchase invoice.</summary>
public record PurchaseItemDto(
    Guid ProductId,
    decimal Quantity,
    decimal UnitCost
);
