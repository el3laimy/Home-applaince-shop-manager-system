using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Application.Services;

/// <summary>
/// Encapsulates all purchase-invoice business logic, isolating it from the HTTP layer.
/// Applies: N+1 fix, atomic SQL stock/cost updates, and safe post-commit cache invalidation.
/// </summary>
public class PurchaseService : IPurchaseService
{
    private readonly DbContext _dbContext;
    private readonly IProductCacheService _productCacheService;
    private readonly IAccountingService _accountingService;

    public PurchaseService(
        DbContext dbContext,
        IProductCacheService productCacheService,
        IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  CREATE
    // ─────────────────────────────────────────────────────────────────────────
    public async Task<PurchaseCreateResponse> CreatePurchaseInvoiceAsync(
        PurchaseCreateDto dto,
        string createdBy,
        CancellationToken cancellationToken)
    {
        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // ── 1. Treasury check (guard before any writes) ──────────────────
            if (dto.PaidAmount > 0)
            {
                var totalCash = await _dbContext.Set<CashTransaction>()
                    .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount, cancellationToken);

                if (dto.PaidAmount > totalCash)
                    throw new InvalidOperationException(
                        $"عذراً، الرصيد الحالي للخزينة ({totalCash} ج.م) لا يكفي لتسديد هذه الدفعة النقدية.");
            }

            bool isDraft = dto.Status.Equals("Draft", StringComparison.OrdinalIgnoreCase);
            var invoiceStatus = isDraft ? PurchaseInvoiceStatus.Draft : PurchaseInvoiceStatus.Completed;

            var totalAmount = dto.Items.Sum(i => i.Quantity * i.UnitCost);
            var netAmount = totalAmount - dto.Discount;
            var remainingAmount = netAmount - dto.PaidAmount;

            var invoice = new PurchaseInvoice
            {
                InvoiceNo = dto.InvoiceNo,
                SupplierId = dto.SupplierId,
                TotalAmount = totalAmount,
                Discount = dto.Discount,
                NetAmount = netAmount,
                PaidAmount = dto.PaidAmount,
                RemainingAmount = remainingAmount,
                Status = invoiceStatus,
                Notes = dto.Notes,
                CreatedBy = createdBy
            };

            // ── 2. Fix N+1: fetch ALL required products in ONE query ─────────
            var requestedProductIds = dto.Items.Select(i => i.ProductId).Distinct().ToList();
            var productDict = await _dbContext.Set<Product>()
                .Where(p => requestedProductIds.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, cancellationToken);

            // Track which products need cache invalidation after commit
            var cacheKeysToRemove = new HashSet<string>();

            foreach (var item in dto.Items)
            {
                if (!productDict.TryGetValue(item.ProductId, out var product))
                    continue; // skip unknown product IDs

                // Build the invoice line (always, draft or not)
                invoice.Items.Add(new PurchaseInvoiceItem
                {
                    ProductId = product.Id,
                    Quantity = item.Quantity,
                    UnitPrice = item.UnitCost,
                    TotalPrice = item.Quantity * item.UnitCost
                });

                if (!isDraft)
                {
                    // ── 3. WAC & Stock — atomic SQL, no EF state tracking ────
                    // WAC = ((Old Qty * Old Price) + (New Qty * New Price)) / (Old Qty + New Qty)
                    var newWac = ((product.StockQuantity * product.PurchasePrice)
                                 + (item.Quantity * item.UnitCost))
                                 / (product.StockQuantity + item.Quantity);

                    await _dbContext.Database.ExecuteSqlInterpolatedAsync(
                        $"UPDATE Products SET StockQuantity = StockQuantity + {item.Quantity}, PurchasePrice = {newWac} WHERE Id = {product.Id}",
                        cancellationToken);

                    // Stock movement (for audit trail)
                    _dbContext.Set<StockMovement>().Add(new StockMovement
                    {
                        ProductId = product.Id,
                        Type = StockMovementType.Purchase,
                        Quantity = (int)item.Quantity,
                        BalanceAfter = (int)(product.StockQuantity + item.Quantity),
                        ReferenceId = invoice.Id,
                        ReferenceNumber = invoice.InvoiceNo,
                        CreatedBy = createdBy
                    });

                    // Queue cache keys for post-commit invalidation
                    if (!string.IsNullOrEmpty(product.GlobalBarcode))
                        cacheKeysToRemove.Add(product.GlobalBarcode);
                    if (!string.IsNullOrEmpty(product.InternalBarcode))
                        cacheKeysToRemove.Add(product.InternalBarcode);
                }
            }

            _dbContext.Set<PurchaseInvoice>().Add(invoice);
            await _dbContext.SaveChangesAsync(cancellationToken);

            if (!isDraft)
            {
                // Accounting: purchase obligation + optional supplier payment
                await _accountingService.RecordPurchaseInvoiceAsync(invoice, createdBy);

                if (dto.PaidAmount > 0)
                    await _accountingService.RecordSupplierPaymentAsync(
                        dto.SupplierId, dto.PaidAmount,
                        $"PAY-{dto.InvoiceNo ?? invoice.Id.ToString()}", createdBy);
            }

            await transaction.CommitAsync(cancellationToken);

            // ── 4. Safe Cache Invalidation: only AFTER commit ────────────────
            foreach (var key in cacheKeysToRemove)
                await _productCacheService.RemoveProductCacheAsync(key, cancellationToken);

            return new PurchaseCreateResponse(invoice.Id, invoice.InvoiceNo, invoice.NetAmount, invoice.RemainingAmount);
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw; // re-throw so controller maps it to BadRequest
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  APPROVE DRAFT
    // ─────────────────────────────────────────────────────────────────────────
    public async Task<PurchaseApproveResponse> ApproveDraftAsync(
        Guid invoiceId,
        string createdBy,
        CancellationToken cancellationToken)
    {
        var invoice = await _dbContext.Set<PurchaseInvoice>()
            .Include(p => p.Items)
            .FirstOrDefaultAsync(p => p.Id == invoiceId, cancellationToken);

        if (invoice == null)
            throw new KeyNotFoundException("الفاتورة غير موجودة.");

        if (invoice.Status != PurchaseInvoiceStatus.Draft)
            throw new InvalidOperationException("هذه الفاتورة ليست مسودة — لا يمكن اعتمادها.");

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // ── 1. Treasury check ─────────────────────────────────────────────
            if (invoice.PaidAmount > 0)
            {
                var totalCash = await _dbContext.Set<CashTransaction>()
                    .SumAsync(t => t.Type == TransactionType.CashIn ? t.Amount : -t.Amount, cancellationToken);

                if (invoice.PaidAmount > totalCash)
                    throw new InvalidOperationException($"رصيد الصندوق ({totalCash} ج.م) لا يكفي.");
            }

            // ── 2. Fix N+1: fetch ALL required products in ONE query ─────────
            var productIds = invoice.Items.Select(i => i.ProductId).Distinct().ToList();
            var productDict = await _dbContext.Set<Product>()
                .Where(p => productIds.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, cancellationToken);

            var cacheKeysToRemove = new HashSet<string>();

            foreach (var item in invoice.Items)
            {
                if (!productDict.TryGetValue(item.ProductId, out var product))
                    continue;

                // ── 3. Atomic WAC + stock update ─────────────────────────────
                var newWac = ((product.StockQuantity * product.PurchasePrice)
                             + (item.Quantity * item.UnitPrice))
                             / (product.StockQuantity + item.Quantity);

                await _dbContext.Database.ExecuteSqlInterpolatedAsync(
                    $"UPDATE Products SET StockQuantity = StockQuantity + {item.Quantity}, PurchasePrice = {newWac} WHERE Id = {product.Id}",
                    cancellationToken);

                _dbContext.Set<StockMovement>().Add(new StockMovement
                {
                    ProductId = product.Id,
                    Type = StockMovementType.Purchase,
                    Quantity = (int)item.Quantity,
                    BalanceAfter = (int)(product.StockQuantity + item.Quantity),
                    ReferenceId = invoice.Id,
                    ReferenceNumber = invoice.InvoiceNo,
                    CreatedBy = createdBy
                });

                if (!string.IsNullOrEmpty(product.GlobalBarcode))
                    cacheKeysToRemove.Add(product.GlobalBarcode);
                if (!string.IsNullOrEmpty(product.InternalBarcode))
                    cacheKeysToRemove.Add(product.InternalBarcode);
            }

            invoice.Status = PurchaseInvoiceStatus.Completed;
            await _dbContext.SaveChangesAsync(cancellationToken);

            // Accounting
            await _accountingService.RecordPurchaseInvoiceAsync(invoice, createdBy);
            if (invoice.PaidAmount > 0)
                await _accountingService.RecordSupplierPaymentAsync(
                    invoice.SupplierId, invoice.PaidAmount,
                    $"PAY-{invoice.InvoiceNo ?? invoice.Id.ToString()}", createdBy);

            await transaction.CommitAsync(cancellationToken);

            // ── 4. Safe Cache Invalidation: only AFTER commit ─────────────────
            foreach (var key in cacheKeysToRemove)
                await _productCacheService.RemoveProductCacheAsync(key, cancellationToken);

            return new PurchaseApproveResponse(
                "تم اعتماد الفاتورة وتحديث المخزون بنجاح.",
                invoice.Id,
                invoice.Status.ToString());
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }
}
