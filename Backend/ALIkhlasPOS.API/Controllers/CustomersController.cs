using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Microsoft.AspNetCore.Authorization.Authorize]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public CustomersController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public record CreateCustomerRequest(string Name, string? Phone, string? Address, string? Notes);
    public record UpdateCustomerRequest(string Name, string? Phone, string? Address, string? Notes);

    // GET /api/customers
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? search = null, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Customers.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(c => c.Name.Contains(search) || (c.Phone != null && c.Phone.Contains(search)));

        var customers = await query.OrderBy(c => c.Name).ToListAsync(cancellationToken);
        return Ok(customers);
    }

    // GET /api/customers/{id}
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();
        return Ok(customer);
    }

    // GET /api/customers/{id}/statement — Customer account statement
    [HttpGet("{id:guid}/statement")]
    public async Task<IActionResult> GetStatement(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();

        var invoices = await _dbContext.Invoices
            .Include(i => i.Items)
            .Where(i => i.CustomerId == id)
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync(cancellationToken);

        var installments = await _dbContext.Installments
            .Where(inst => invoices.Select(i => i.Id).Contains(inst.InvoiceId))
            .ToListAsync(cancellationToken);

        return Ok(new
        {
            Customer = customer,
            Invoices = invoices,
            Installments = installments,
            TotalDue = invoices.Sum(i => i.TotalAmount),
            TotalPaid = installments.Where(i => i.Status == InstallmentStatus.Paid).Sum(i => i.Amount),
            RemainingBalance = invoices.Sum(i => i.TotalAmount) - installments.Where(i => i.Status == InstallmentStatus.Paid).Sum(i => i.Amount)
        });
    }

    // POST /api/customers
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateCustomerRequest request, CancellationToken cancellationToken)
    {
        var customer = new Customer
        {
            Name = request.Name,
            Phone = request.Phone,
            Address = request.Address,
            Notes = request.Notes
        };
        _dbContext.Customers.Add(customer);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = customer.Id }, customer);
    }

    // PUT /api/customers/{id}
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateCustomerRequest request, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();

        customer.Name = request.Name;
        customer.Phone = request.Phone;
        customer.Address = request.Address;
        customer.Notes = request.Notes;

        await _dbContext.SaveChangesAsync(cancellationToken);
        return Ok(customer);
    }

    // DELETE /api/customers/{id}
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var customer = await _dbContext.Customers.FindAsync(new object[] { id }, cancellationToken);
        if (customer == null) return NotFound();
        _dbContext.Customers.Remove(customer);
        await _dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}
