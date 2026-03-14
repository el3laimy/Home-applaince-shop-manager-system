using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.DTOs.Invoices;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Application.Services;

public class InvoiceService : IInvoiceService
{
    private readonly DbContext _dbContext;
    private readonly IProductCacheService _productCacheService;
    private readonly IAccountingService _accountingService;

    public InvoiceService(
        DbContext dbContext,
        IProductCacheService productCacheService,
        IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
    }

    public async Task<InvoiceCreateResponse> CreateInvoiceAsync(
        InvoiceCreateDto request,
        Guid? cashierId,
        string createdBy,
        bool isAdmin,
        CancellationToken cancellationToken)
    {
        if (request.ScannedItems == null || !request.ScannedItems.Any())
            throw new ArgumentException("يجب أن تحتوي الفاتورة على صنف واحد على الأقل.");

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            // Invoice Number — retry loop for unique constraint safety
            string invoiceNo = string.Empty;
            var today = DateTime.UtcNow.ToString("yyyyMMdd");
            for (int attempt = 0; attempt < 5; attempt++)
            {
                var lastNo = await _dbContext.Set<Invoice>()
                    .Where(i => i.InvoiceNo.StartsWith($"INV-{today}-"))
                    .OrderByDescending(i => i.InvoiceNo)
                    .Select(i => i.InvoiceNo)
                    .FirstOrDefaultAsync(cancellationToken);

                int seq = 1;
                if (lastNo != null)
                {
                    var parts = lastNo.Split('-');
                    if (parts.Length == 3 && int.TryParse(parts[2], out var lastSeq))
                        seq = lastSeq + 1;
                }
                invoiceNo = $"INV-{today}-{seq:D5}";

                // Check if this number already exists (race guard)
                if (!await _dbContext.Set<Invoice>().AnyAsync(i => i.InvoiceNo == invoiceNo, cancellationToken))
                    break;

                if (attempt == 4)
                    throw new InvalidOperationException("فشل في توليد رقم فاتورة فريد. يرجى المحاولة مرة أخرى.");
            }

            var invoice = new Invoice
            {
                InvoiceNo = invoiceNo,
                PaymentType = request.PaymentType,
                Status = request.Status,
                CustomerId = request.CustomerId,
                CashierId = cashierId,
                DiscountAmount = request.DiscountAmount,
                VatRate = request.VatRate,
                Notes = request.Notes,
                IsBridal = request.IsBridal,
                EventDate = request.EventDate,
                DeliveryDate = request.DeliveryDate,
                BridalNotes = request.BridalNotes,
                InterestRate = request.InterestRate,
                InstallmentPeriod = request.InstallmentPeriod,
                InstallmentCount = request.InstallmentCount,
                CreatedBy = createdBy,
                PaymentReference = request.PaymentReference
            };

            var groupedScans = request.ScannedItems
                .GroupBy(i => new { i.Barcode, i.CustomPrice })
                .Select(g => new { g.Key.Barcode, g.Key.CustomPrice, Quantity = g.Sum(x => x.Quantity) })
                .ToList();

            // 1. Fix N+1 Query Problem: Extract barcodes and hit cache / DB ONCE
            var uniqueBarcodes = groupedScans.Select(s => s.Barcode).Distinct().ToList();
            var productDict = new Dictionary<string, Product>();

            foreach (var barcode in uniqueBarcodes)
            {
                var p = await _productCacheService.GetProductByBarcodeAsync(barcode, cancellationToken);
                if (p != null)
                    productDict[barcode] = p;
                else
                    throw new InvalidOperationException($"لا يوجد منتج بهذا الباركود: {barcode}");
            }

            var productIds = productDict.Values.Select(p => p.Id).Distinct().ToList();
            var allBundles = await _dbContext.Set<Bundle>()
                .Where(b => productIds.Contains(b.ParentProductId))
                .ToListAsync(cancellationToken);

            var subProductIds = allBundles.Select(b => b.SubProductId).Distinct().ToList();
            var subProducts = await _dbContext.Set<Product>()
                .Where(p => subProductIds.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, cancellationToken);

            // 2. Safe Cache Invalidation: Keep track to update AFTER commit
            var cacheKeysToUpdate = new HashSet<Product>();
            var cacheKeysToRemove = new HashSet<string>();

            foreach (var scan in groupedScans)
            {
                var barcode = scan.Barcode;
                var quantity = scan.Quantity;
                var customPrice = scan.CustomPrice;

                var product = productDict[barcode];
                var bundleComponents = allBundles.Where(b => b.ParentProductId == product.Id).ToList();

                if (bundleComponents.Any())
                {
                    foreach (var bundleItem in bundleComponents)
                    {
                        if (subProducts.TryGetValue(bundleItem.SubProductId, out var subProduct))
                        {
                            int totalSubQtyRequired = bundleItem.QuantityRequired * quantity;
                            
                            // 3. Concurrency Fix: Raw SQL decrement with optimistic concurrency
                            int rowsAffected = await _dbContext.Database.ExecuteSqlInterpolatedAsync(
                                $"UPDATE Products SET StockQuantity = StockQuantity - {totalSubQtyRequired} WHERE Id = {subProduct.Id} AND StockQuantity >= {totalSubQtyRequired}", 
                                cancellationToken);
                            
                            if (rowsAffected == 0)
                                throw new InvalidOperationException($"الكمية غير كافية للمنتج المكوّن: {subProduct.Name}. المتاح: {subProduct.StockQuantity}");

                            // Detach to prevent EF from overwriting the atomically-updated DB value
                            _dbContext.Entry(subProduct).State = Microsoft.EntityFrameworkCore.EntityState.Detached;
                            var refreshedSubQty = await _dbContext.Set<Product>().Where(p => p.Id == subProduct.Id).Select(p => p.StockQuantity).FirstAsync(cancellationToken);
                            
                            _dbContext.Set<StockMovement>().Add(new StockMovement
                            {
                                ProductId = subProduct.Id,
                                Type = StockMovementType.Sale,
                                Quantity = -(int)totalSubQtyRequired,
                                BalanceAfter = (int)refreshedSubQty,
                                ReferenceId = invoice.Id,
                                ReferenceNumber = invoice.InvoiceNo,
                                CreatedBy = invoice.CreatedBy,
                                Notes = $"مرتبط بالمنتج المجمّع {product.Name}"
                            });
                            
                            if (!string.IsNullOrEmpty(subProduct.GlobalBarcode))
                                cacheKeysToRemove.Add(subProduct.GlobalBarcode);
                            if (!string.IsNullOrEmpty(subProduct.InternalBarcode))
                                cacheKeysToRemove.Add(subProduct.InternalBarcode);
                        }
                    }
                }
                else
                {
                    // 3. Concurrency Fix: Raw SQL decrement with optimistic concurrency
                    int rowsAffected = await _dbContext.Database.ExecuteSqlInterpolatedAsync(
                        $"UPDATE Products SET StockQuantity = StockQuantity - {quantity} WHERE Id = {product.Id} AND StockQuantity >= {quantity}", 
                        cancellationToken);

                    if (rowsAffected == 0)
                        throw new InvalidOperationException($"الكمية غير كافية للمنتج: {product.Name}. المطلوب: {quantity}");

                    // Detach to prevent EF from overwriting the atomically-updated DB value
                    _dbContext.Entry(product).State = Microsoft.EntityFrameworkCore.EntityState.Detached;
                    var refreshedQty = await _dbContext.Set<Product>().Where(p => p.Id == product.Id).Select(p => p.StockQuantity).FirstAsync(cancellationToken);

                    _dbContext.Set<StockMovement>().Add(new StockMovement
                    {
                        ProductId = product.Id,
                        Type = StockMovementType.Sale,
                        Quantity = -(int)quantity,
                        BalanceAfter = (int)refreshedQty,
                        ReferenceId = invoice.Id,
                        ReferenceNumber = invoice.InvoiceNo,
                        CreatedBy = invoice.CreatedBy
                    });
                }

                cacheKeysToUpdate.Add(product);
                
                decimal finalPrice = product.Price;
                if (customPrice.HasValue)
                {
                    if (customPrice.Value < product.PurchasePrice && !isAdmin)
                    {
                        throw new InvalidOperationException($"لا يمكن بيع المنتج {product.Name} بسعر أقل من التكلفة ({product.PurchasePrice}).");
                    }
                    finalPrice = customPrice.Value;
                }

                invoice.Items.Add(new InvoiceItem
                {
                    ProductId = product.Id,
                    Quantity = quantity,
                    UnitPrice = finalPrice
                });
            }

            // ── Financial calculations ────────────────────────────────────────────
            var subTotal = invoice.Items.Sum(i => i.TotalPrice);

            var effectiveVatRate = request.VatRate;
            if (effectiveVatRate == 0)
            {
                var shopSettings = await _dbContext.Set<ShopSettings>().FirstOrDefaultAsync(cancellationToken);
                if (shopSettings?.VatEnabled == true)
                    effectiveVatRate = shopSettings.DefaultVatRate;
            }

            var vatAmount = Math.Round((subTotal - request.DiscountAmount) * (effectiveVatRate / 100m), 2);
            var totalAmount = subTotal - request.DiscountAmount + vatAmount;

            invoice.SubTotal = subTotal;
            invoice.VatRate = effectiveVatRate;
            invoice.VatAmount = vatAmount;
            invoice.TotalAmount = totalAmount;

            // Payment tracking for installments
            if (request.PaymentType == PaymentType.Installment)
            {
                invoice.PaidAmount = request.DownPayment;
                var remaining = totalAmount - request.DownPayment;
                var interest = remaining * (request.InterestRate / 100m);
                var totalWithInterest = remaining + interest;
                invoice.RemainingAmount = totalWithInterest;
                invoice.TotalAmount = totalAmount + interest; 
            }
            else
            {
                invoice.PaidAmount = totalAmount;
                invoice.RemainingAmount = 0;
            }

            // ── Recording to Treasury & Accounting ──
            if (invoice.CustomerId.HasValue)
            {
                var customer = await _dbContext.Set<Customer>().FindAsync(new object[] { invoice.CustomerId.Value }, cancellationToken);
                if (customer != null)
                {
                    customer.TotalPurchases += invoice.TotalAmount;
                    customer.TotalPaid += invoice.PaidAmount;
                }
            }

            _dbContext.Set<Invoice>().Add(invoice);
            await _dbContext.SaveChangesAsync(cancellationToken);

            await _accountingService.RecordCashSaleAsync(invoice, invoice.CreatedBy, request.SplitCashAmount, request.SplitVisaAmount);
            
            await transaction.CommitAsync(cancellationToken);

            // 4. Safe Cache Invalidation: Only update cache IF transaction succeeded
            foreach(var p in cacheKeysToUpdate)
            {
                await _productCacheService.SetProductCacheAsync(p, cancellationToken);
            }
            foreach(var b in cacheKeysToRemove)
            {
                await _productCacheService.RemoveProductCacheAsync(b, cancellationToken);
            }

            return new InvoiceCreateResponse(
                invoice.Id,
                invoice.InvoiceNo,
                invoice.SubTotal,
                invoice.DiscountAmount,
                invoice.VatAmount,
                invoice.TotalAmount,
                invoice.PaidAmount,
                invoice.RemainingAmount,
                invoice.Items.Count
            );
        }
        catch (Exception)
        {
            await transaction.RollbackAsync(cancellationToken);
            // Re-throw so the controller can handle it (ArgumentException, InvalidOperationException, etc.)
            throw;
        }
    }
}
