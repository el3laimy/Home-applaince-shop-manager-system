using System;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.DTOs.Invoices;

namespace ALIkhlasPOS.Application.Interfaces;

public interface IInvoiceService
{
    Task<InvoiceCreateResponse> CreateInvoiceAsync(
        InvoiceCreateDto request, 
        Guid? cashierId, 
        string createdBy, 
        bool isAdmin,
        CancellationToken cancellationToken);
}
