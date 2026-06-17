using System;
using System.Threading;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.Application.Interfaces;

public interface IProductService
{
    Task<ProductOperationResponse> CreateProductAsync(CreateProductDto dto, CancellationToken cancellationToken);
    Task<ProductOperationResponse> UpdateProductAsync(Guid id, UpdateProductDto dto, string createdBy, CancellationToken cancellationToken);
    Task<ProductOperationResponse> AdjustStockAsync(Guid id, AdjustStockDto dto, string createdBy, CancellationToken cancellationToken);
    Task<bool> DeleteProductAsync(Guid id, CancellationToken cancellationToken);
}

// DTOs
public record CreateProductDto(string Name, string? Description, string? CategoryName, decimal Price, decimal PurchasePrice, decimal WholesalePrice, int StockQuantity, int? MinStockLevel, string? GlobalBarcode, string? InternalBarcode, decimal? VatRate, bool GenerateBarcode = false);
public record UpdateProductDto(string Name, string? Description, string? CategoryName, decimal Price, decimal PurchasePrice, decimal WholesalePrice, int StockQuantity, int? MinStockLevel, string? GlobalBarcode, string? InternalBarcode, decimal? VatRate);
public record AdjustStockDto(int AdjustmentQuantity, string Reason, decimal? CostPerUnit);

// Responses
public record ProductOperationResponse(bool Success, string Message, Product? Product);
