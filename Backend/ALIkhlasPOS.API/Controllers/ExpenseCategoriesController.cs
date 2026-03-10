using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Domain.Entities;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Authorize(Roles = "Admin,Manager")]
[Route("api/[controller]")]
public class ExpenseCategoriesController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public ExpenseCategoriesController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    [HttpGet]
    public async Task<IActionResult> GetCategories(CancellationToken ct)
    {
        var categories = await _dbContext.ExpenseCategories
            .Where(c => c.IsActive)
            .OrderBy(c => c.Name)
            .ToListAsync(ct);
            
        return Ok(categories);
    }

    [HttpPost]
    public async Task<IActionResult> CreateCategory([FromBody] CreateCategoryRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            return BadRequest("Category name is required.");

        var exists = await _dbContext.ExpenseCategories.AnyAsync(c => c.Name.ToLower() == request.Name.ToLower() && c.IsActive, ct);
        if (exists)
            return BadRequest("التصنيف موجود بالفعل.");

        var category = new ExpenseCategory { Name = request.Name.Trim() };
        _dbContext.ExpenseCategories.Add(category);
        await _dbContext.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetCategories), new { id = category.Id }, category);
    }
}

public class CreateCategoryRequest
{
    public string Name { get; set; } = string.Empty;
}
