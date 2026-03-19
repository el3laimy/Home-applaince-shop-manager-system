using System;
using System.Collections.Generic;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.Application.DTOs.Invoices;

public record ScanItemDto(string Barcode, int Quantity = 1, decimal? CustomPrice = null);

public record InvoiceCreateDto(
    List<ScanItemDto> ScannedItems,
    PaymentType PaymentType,
    Guid? CustomerId = null,
    decimal DiscountAmount = 0,
    decimal DownPayment = 0,        
    decimal VatRate = 0,            
    decimal InterestRate = 0,       
    InstallmentPeriod InstallmentPeriod = InstallmentPeriod.Monthly, 
    int InstallmentCount = 0,       
    InvoiceStatus Status = InvoiceStatus.Completed,
    string? Notes = null,
    bool IsBridal = false,
    DateTime? EventDate = null,
    DateTime? DeliveryDate = null,
    string? BridalNotes = null,
    string? PaymentReference = null, 
    decimal SplitCashAmount = 0,    
    decimal SplitVisaAmount = 0     
);

public record InvoiceCreateResponse(
    Guid Id,
    string InvoiceNo,
    decimal SubTotal,
    decimal DiscountAmount,
    decimal VatAmount,
    decimal TotalAmount,
    decimal PaidAmount,
    decimal RemainingAmount,
    int ItemCount
);
