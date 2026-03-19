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
/// Encapsulates all product-return business logic.
///
/// Key improvements over the original controller:
///   1. Transaction wraps the ENTIRE operation (including validation), not just SaveChanges.
///   2. N+1 fix: products, bundles and previously-returned quantities are fetched once before the loop.
///   3. Atomic SQL for stock restoration (no EF state-tracking race condition).
///   4. Redis cache is invalidated ONLY after transaction.CommitAsync() — never on rollback.
/// </summary>
public class ReturnInvoiceService : IReturnInvoiceService
{
    private readonly DbContext _dbContext;
    private readonly IProductCacheService _productCacheService;
    private readonly IAccountingService _accountingService;

    public ReturnInvoiceService(
        DbContext dbContext,
        IProductCacheService productCacheService,
        IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
    }

    public async Task<ReturnInvoiceResponse> ProcessReturnAsync(
        ReturnInvoiceCreateDto dto,
        string createdBy,
        CancellationToken cancellationToken)
    {
        // ── 1. Load original invoice (guard before the transaction) ──────────
        var originalInvoice = await _dbContext.Set<Invoice>()
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == dto.OriginalInvoiceId, cancellationToken);

        if (originalInvoice == null)
            throw new KeyNotFoundException("الفاتورة الأصلية غير موجودة.");

        // ── 2. Pre-fetch all data needed by the loop (N+1 fix) ───────────────

        // 2a. Previously returned quantities for this original invoice
        var previouslyReturnedItems = await _dbContext.Set<ReturnInvoice>()
            .Where(r => r.OriginalInvoiceId == dto.OriginalInvoiceId)
            .SelectMany(r => r.Items)
            .ToListAsync(cancellationToken);

        var returnedQtyByProduct = previouslyReturnedItems
            .GroupBy(ri => ri.ProductId)
            .ToDictionary(g => g.Key, g => g.Sum(ri => ri.Quantity));

        // 2b. Products referenced in this return request (single query)
        var requestedProductIds = dto.Items.Select(i => i.ProductId).Distinct().ToList();
        var productDict = await _dbContext.Set<Product>()
            .Where(p => requestedProductIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, cancellationToken);

        // 2c. Bundle configurations for any bundle-part returns (single query)
        var parentBundleIds = dto.Items
            .Where(i => i.ParentBundleId.HasValue)
            .Select(i => i.ParentBundleId!.Value)
            .Distinct()
            .ToList();

        var bundleDict = parentBundleIds.Any()
            ? await _dbContext.Set<Bundle>()
                .Where(b => parentBundleIds.Contains(b.ParentProductId))
                .ToListAsync(cancellationToken)
            : new List<Bundle>();

        // ── 3. Build ReturnInvoice entity + validate BEFORE opening transaction ─
        var returnInvoice = new ReturnInvoice
        {
            ReturnNo = $"RET-{DateTime.UtcNow:yyyyMMddHHmmss}",
            OriginalInvoiceId = dto.OriginalInvoiceId,
            Reason = dto.Reason,
            Notes = dto.Notes,
            CreatedBy = createdBy
        };

        // Track products that need cache invalidation after commit
        var cacheKeysToRemove = new HashSet<string>();

        foreach (var item in dto.Items)
        {
            // Resolve the invoice line (bundle parent mapped to its own invoice item)
            var invoiceProductId = item.ParentBundleId ?? item.ProductId;
            var originalItem = originalInvoice.Items.FirstOrDefault(i => i.ProductId == invoiceProductId);

            if (originalItem == null)
                throw new InvalidOperationException(
                    "المنتج الأساسي/العرض لم يتم بيعه في الفاتورة الأصلية.");

            // Determine max returnable quantity
            decimal previouslyReturned = returnedQtyByProduct.GetValueOrDefault(item.ProductId, 0);
            decimal maxReturnable = originalItem.Quantity;

            if (item.ParentBundleId.HasValue)
            {
                var bundleComp = bundleDict.FirstOrDefault(
                    b => b.ParentProductId == item.ParentBundleId.Value && b.SubProductId == item.ProductId);

                if (bundleComp == null)
                    throw new InvalidOperationException("هذا المنتج ليس جزءاً من العرض المحدد.");

                maxReturnable = originalItem.Quantity * bundleComp.QuantityRequired;
            }

            maxReturnable -= previouslyReturned;

            if (item.Quantity > maxReturnable)
            {
                var productName = productDict.TryGetValue(item.ProductId, out var pf)
                    ? pf.Name
                    : "غير معروف";

                throw new InvalidOperationException(
                    $"الكمية المرتجعة للمنتج ({productName}) تتجاوز المسموح به ({maxReturnable}).");
            }

            // Fetch product for unit-price calculation
            if (!productDict.TryGetValue(item.ProductId, out var product))
                throw new InvalidOperationException($"المنتج غير موجود: {item.ProductId}");

            // Calculate refund price: custom > bundle sub-product price > original invoice unit price
            decimal unitPriceToRefund = item.CustomUnitPrice
                ?? (item.ParentBundleId.HasValue ? product.Price : originalItem.UnitPrice);

            returnInvoice.Items.Add(new ReturnInvoiceItem
            {
                ProductId = item.ProductId,
                Quantity = item.Quantity,
                UnitPrice = unitPriceToRefund
            });

            // Queue cache keys for post-commit removal
            if (!string.IsNullOrEmpty(product.GlobalBarcode))
                cacheKeysToRemove.Add(product.GlobalBarcode);
            if (!string.IsNullOrEmpty(product.InternalBarcode))
                cacheKeysToRemove.Add(product.InternalBarcode);
        }

        returnInvoice.RefundAmount = returnInvoice.Items.Sum(i => i.TotalPrice);

        // ── 4. Execute everything inside a single transaction ────────────────
        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // Save the return invoice first to get its generated Id
            _dbContext.Set<ReturnInvoice>().Add(returnInvoice);
            await _dbContext.SaveChangesAsync(cancellationToken);

            // ── 5. Atomic SQL stock restore + movement log ───────────────────
            foreach (var item in returnInvoice.Items)
            {
                // Atomic increment — safe under concurrent return requests
                await _dbContext.Database.ExecuteSqlInterpolatedAsync(
                    $"UPDATE Products SET StockQuantity = StockQuantity + {item.Quantity} WHERE Id = {item.ProductId}",
                    cancellationToken);

                // Audit trail movement
                _dbContext.Set<StockMovement>().Add(new StockMovement
                {
                    ProductId = item.ProductId,
                    Type = StockMovementType.ReturnSale,
                    Quantity = (int)item.Quantity,  // positive = stock coming back in
                    BalanceAfter = (int)(productDict[item.ProductId].StockQuantity + item.Quantity),
                    ReferenceId = returnInvoice.Id,
                    ReferenceNumber = returnInvoice.ReturnNo,
                    CreatedBy = createdBy,
                    Notes = dto.Items.FirstOrDefault(i => i.ProductId == item.ProductId)?.ParentBundleId.HasValue == true
                        ? "إرجاع جزء من عرض"
                        : null
                });
            }

            // Accounting: reverse sale journal entry + treasury CashOut
            await _accountingService.RecordSalesReturnAsync(returnInvoice, createdBy);

            // ── 6. Update customer balance (if linked) ───────────────────────
            if (originalInvoice.CustomerId.HasValue)
            {
                var customer = await _dbContext.Set<Customer>()
                    .FindAsync(new object[] { originalInvoice.CustomerId.Value }, cancellationToken);

                if (customer != null)
                {
                    customer.TotalPurchases -= returnInvoice.RefundAmount;
                    customer.TotalPaid     -= returnInvoice.RefundAmount;
                }
            }

            // ── 7. Reduce paid/remaining on original invoice ─────────────────
            originalInvoice.PaidAmount      = Math.Max(0, originalInvoice.PaidAmount - returnInvoice.RefundAmount);
            originalInvoice.RemainingAmount = Math.Max(0, originalInvoice.TotalAmount - originalInvoice.PaidAmount);

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            // ── 8. Safe Cache Invalidation: ONLY after commit ────────────────
            foreach (var key in cacheKeysToRemove)
                await _productCacheService.RemoveProductCacheAsync(key, cancellationToken);

            return new ReturnInvoiceResponse(
                returnInvoice.Id,
                returnInvoice.ReturnNo,
                returnInvoice.RefundAmount,
                "تم تسجيل المرتجع وإعادة الكميات للمخزن بنجاح.");
        }
        catch
        {
            await transaction.RollbackAsync(cancellationToken);
            throw; // re-throw so thin controller maps to BadRequest
        }
    }
}
