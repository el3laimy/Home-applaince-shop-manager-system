using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ALIkhlasPOS.Infrastructure.Data;

namespace ALIkhlasPOS.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AuditLogsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public AuditLogsController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    // GET: api/auditlogs?page=1&pageSize=50&search=&table=&action=
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50,
        [FromQuery] string? search = null,
        [FromQuery] string? table = null,
        [FromQuery] string? action = null,
        CancellationToken cancellationToken = default)
    {
        var query = _dbContext.AuditLogs.AsQueryable();

        if (!string.IsNullOrWhiteSpace(table))
            query = query.Where(a => a.TableName == table);

        if (!string.IsNullOrWhiteSpace(action))
            query = query.Where(a => a.Action == action);

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(a =>
                a.TableName.Contains(search) ||
                a.CreatedBy.Contains(search) ||
                a.RecordId.Contains(search) ||
                (a.NewValues != null && a.NewValues.Contains(search)));

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(a => a.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(a => new
            {
                a.Id,
                a.TableName,
                a.RecordId,
                a.Action,
                a.OldValues,
                a.NewValues,
                a.CreatedBy,
                a.CreatedAt
            })
            .ToListAsync(cancellationToken);

        return Ok(new
        {
            items,
            totalCount,
            page,
            pageSize,
            totalPages = (int)Math.Ceiling(totalCount / (double)pageSize)
        });
    }

    // GET: api/auditlogs/tables — list distinct table names for filtering
    [HttpGet("tables")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetTables(CancellationToken cancellationToken)
    {
        var tables = await _dbContext.AuditLogs
            .Select(a => a.TableName)
            .Distinct()
            .OrderBy(t => t)
            .ToListAsync(cancellationToken);
        return Ok(tables);
    }
}
