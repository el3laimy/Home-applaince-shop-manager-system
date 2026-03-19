using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Interfaces.Accounting;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Infrastructure.Services;

public class ProductService : IProductService
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IBarcodeService _barcodeService;
    private readonly IProductCacheService _productCacheService;
    private readonly IAccountingService _accountingService;

    public ProductService(ApplicationDbContext dbContext, IBarcodeService barcodeService, IProductCacheService productCacheService, IAccountingService accountingService)
    {
        _dbContext = dbContext;
        _barcodeService = barcodeService;
        _productCacheService = productCacheService;
        _accountingService = accountingService;
    }

    public async Task<ProductOperationResponse> CreateProductAsync(CreateProductDto dto, CancellationToken cancellationToken)
    {
        var product = new Product
        {
            Name = dto.Name,
            Price = dto.Price,
            PurchasePrice = dto.PurchasePrice,
            WholesalePrice = dto.WholesalePrice,
            StockQuantity = dto.StockQuantity,
            MinStockAlert = dto.MinStockLevel ?? 0,
            Category = dto.CategoryName,
            Description = dto.Description
        };

        if (!string.IsNullOrWhiteSpace(dto.GlobalBarcode) && !_barcodeService.ValidateBarcodeFormat(dto.GlobalBarcode))
            return new ProductOperationResponse(false, "صيغة الباركود غير صحيحة.", null);

        if (!string.IsNullOrWhiteSpace(dto.GlobalBarcode) 
            && dto.GlobalBarcode.Length == 13 
            && dto.GlobalBarcode.All(char.IsDigit)
            && !_barcodeService.ValidateEAN13Checksum(dto.GlobalBarcode))
            return new ProductOperationResponse(false, "خانة التحقق (Check Digit) في الباركود EAN-13 غير صحيحة. تأكد من الرقم المدخل.", null);

        if (string.IsNullOrWhiteSpace(dto.GlobalBarcode))
        {
            product.GlobalBarcode = null;
            product.InternalBarcode = await _barcodeService.GenerateInternalBarcodeAsync(cancellationToken);
        }
        else
        {
            product.GlobalBarcode = dto.GlobalBarcode;
            product.InternalBarcode = null;
        }

        var checkingBarcodes = new List<string>();
        if (!string.IsNullOrWhiteSpace(product.GlobalBarcode)) checkingBarcodes.Add(product.GlobalBarcode);
        if (!string.IsNullOrWhiteSpace(product.InternalBarcode)) checkingBarcodes.Add(product.InternalBarcode);

        bool barcodeExists = checkingBarcodes.Any() && await _dbContext.Products.AnyAsync(p => 
            (p.GlobalBarcode != null && checkingBarcodes.Contains(p.GlobalBarcode)) ||
            (p.InternalBarcode != null && checkingBarcodes.Contains(p.InternalBarcode)), 
            cancellationToken);

        if (barcodeExists)
            return new ProductOperationResponse(false, "الباركود مستخدم بالفعل لمنتج آخر.", null);

        _dbContext.Products.Add(product);
        await _dbContext.SaveChangesAsync(cancellationToken);
        await _productCacheService.SetProductCacheAsync(product, cancellationToken);

        return new ProductOperationResponse(true, "تم إضافة المنتج بنجاح", product);
    }

    public async Task<ProductOperationResponse> UpdateProductAsync(Guid id, UpdateProductDto dto, string createdBy, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return new ProductOperationResponse(false, "Product not found", null);

        product.Name = dto.Name;
        product.Price = dto.Price;
        product.PurchasePrice = dto.PurchasePrice;
        product.WholesalePrice = dto.WholesalePrice;
        
        StockAdjustment? stockAdj = null;
        if (product.StockQuantity != dto.StockQuantity)
        {
            var diff = dto.StockQuantity - product.StockQuantity;
            stockAdj = new StockAdjustment
            {
                ProductId = id,
                Type = diff < 0 ? StockAdjustmentType.Damage : StockAdjustmentType.ManualCorrection,
                QuantityAdjusted = (int)diff,
                Cost = Math.Abs(diff) * product.PurchasePrice,
                Reason = "تعديل عبر صفحة المنتج",
                CreatedBy = createdBy
            };
            _dbContext.Set<StockAdjustment>().Add(stockAdj);
            product.StockQuantity = dto.StockQuantity;
        }

        product.MinStockAlert = dto.MinStockLevel ?? 0;
        product.Category = dto.CategoryName;
        product.Description = dto.Description;
        product.UpdatedAt = DateTime.UtcNow;

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await _dbContext.SaveChangesAsync(cancellationToken);
            
            if (stockAdj != null && stockAdj.Cost > 0)
                await _accountingService.RecordStockAdjustmentAsync(stockAdj, createdBy);
            
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return new ProductOperationResponse(false, $"خطأ أثناء حفظ التعديل: {ex.Message}", null);
        }

        await _productCacheService.SetProductCacheAsync(product, cancellationToken);
        return new ProductOperationResponse(true, "تم التعديل بنجاح", product);
    }

    public async Task<ProductOperationResponse> AdjustStockAsync(Guid id, AdjustStockDto dto, string createdBy, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return new ProductOperationResponse(false, "Product not found", null);

        var adjustment = new StockAdjustment
        {
            ProductId = id,
            Type = dto.AdjustmentQuantity < 0 ? StockAdjustmentType.Loss : StockAdjustmentType.ManualCorrection,
            QuantityAdjusted = dto.AdjustmentQuantity,
            Cost = Math.Abs(dto.AdjustmentQuantity) * (dto.CostPerUnit ?? product.PurchasePrice),
            Reason = dto.Reason,
            CreatedBy = createdBy
        };

        product.StockQuantity += dto.AdjustmentQuantity;
        if (product.StockQuantity < 0) product.StockQuantity = 0;
        product.UpdatedAt = DateTime.UtcNow;

        using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            _dbContext.Set<StockAdjustment>().Add(adjustment);
            await _dbContext.SaveChangesAsync(cancellationToken);
            
            if (adjustment.Cost > 0)
                await _accountingService.RecordStockAdjustmentAsync(adjustment, createdBy);
            
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            return new ProductOperationResponse(false, $"خطأ أثناء حفظ التعديل: {ex.Message}", null);
        }

        await _productCacheService.SetProductCacheAsync(product, cancellationToken);
        return new ProductOperationResponse(true, "تم تسوية المخزون بنجاح", product);
    }

    public async Task<bool> DeleteProductAsync(Guid id, CancellationToken cancellationToken)
    {
        var product = await _dbContext.Products.FindAsync(new object[] { id }, cancellationToken);
        if (product == null) return false;

        product.IsActive = false;
        await _dbContext.SaveChangesAsync(cancellationToken);
        
        if (!string.IsNullOrEmpty(product.GlobalBarcode))
            await _productCacheService.RemoveProductCacheAsync(product.GlobalBarcode, cancellationToken);
        if (!string.IsNullOrEmpty(product.InternalBarcode))
            await _productCacheService.RemoveProductCacheAsync(product.InternalBarcode, cancellationToken);

        return true;
    }
}
