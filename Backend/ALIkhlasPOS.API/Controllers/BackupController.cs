using System.IO;
using System.Runtime.InteropServices;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class BackupController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IConfiguration _config;
    private readonly ILogger<BackupController> _logger;

    public BackupController(ApplicationDbContext dbContext, IConfiguration config, ILogger<BackupController> logger)
    {
        _dbContext = dbContext;
        _config = config;
        _logger = logger;
    }

    // ── GET /api/backup/stats — DB statistics for the settings "backup" section ──
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats(CancellationToken ct)
    {
        var counts = new
        {
            Users = await _dbContext.Users.CountAsync(ct),
            Products = await _dbContext.Products.CountAsync(ct),
            Invoices = await _dbContext.Invoices.CountAsync(ct),
            Customers = await _dbContext.Customers.CountAsync(ct),
            Installments = await _dbContext.Installments.CountAsync(ct),
            PurchaseInvoices = await _dbContext.PurchaseInvoices.CountAsync(ct),
            Expenses = await _dbContext.Expenses.CountAsync(ct),
        };

        var totalRecords = counts.Users + counts.Products + counts.Invoices +
                           counts.Customers + counts.Installments +
                           counts.PurchaseInvoices + counts.Expenses;

        return Ok(new
        {
            DatabaseEngine = "PostgreSQL",
            BackupMethod = "pg_dump",
            LastChecked = DateTime.UtcNow,
            TotalRecords = totalRecords,
            Tables = counts
        });
    }

    // ── POST /api/backup/trigger — Trigger pg_dump (Linux/Mac only) ──────────
    [HttpPost("trigger")]
    public async Task<IActionResult> TriggerBackup(CancellationToken ct)
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux) &&
            !RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            return BadRequest(new { message = "النسخ الاحتياطي التلقائي يعمل على Linux/Mac فقط." });

        var connStr = _config.GetConnectionString("DefaultConnection");
        if (string.IsNullOrEmpty(connStr))
            return StatusCode(500, new { message = "لم يتم تكوين اتصال قاعدة البيانات." });

        // Parse connection string to extract pg_dump parameters
        var builder = new Npgsql.NpgsqlConnectionStringBuilder(connStr);
        var backupDir = Path.Combine(Path.GetTempPath(), "alikhlas_backups");
        Directory.CreateDirectory(backupDir);

        var fileName = $"backup_{DateTime.Now:yyyyMMdd_HHmmss}.sql";
        var fullPath = Path.Combine(backupDir, fileName);

        var env = new Dictionary<string, string>
        {
            ["PGPASSWORD"] = builder.Password ?? ""
        };

        var psi = new System.Diagnostics.ProcessStartInfo("pg_dump")
        {
            Arguments = $"-h {builder.Host} -p {builder.Port} -U {builder.Username} -d {builder.Database} -f {fullPath} --no-password",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };

        foreach (var kv in env) psi.Environment[kv.Key] = kv.Value;

        try
        {
            using var process = System.Diagnostics.Process.Start(psi)!;
            var stderr = await process.StandardError.ReadToEndAsync(ct);
            await process.WaitForExitAsync(ct);

            if (process.ExitCode != 0)
            {
                _logger.LogError("pg_dump failed: {Error}", stderr);
                return StatusCode(500, new { message = $"فشل النسخ الاحتياطي: {stderr}" });
            }

            var fileInfo = new FileInfo(fullPath);
            _logger.LogInformation("Backup created: {Path} ({Size})", fullPath, fileInfo.Length);

            return Ok(new
            {
                message = "تم إنشاء النسخة الاحتياطية بنجاح",
                fileName,
                path = fullPath,
                sizeBytes = fileInfo.Length,
                createdAt = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during backup");
            return StatusCode(500, new { message = "خطأ أثناء تنفيذ النسخ الاحتياطي. تأكد من تثبيت pg_dump." });
        }
    }

    // ── GET /api/backup/download/{fileName} — Download a backup file ─────────
    [HttpGet("download/{fileName}")]
    public IActionResult Download(string fileName)
    {
        if (fileName.Contains("..") || fileName.Contains("/"))
            return BadRequest("Invalid filename");

        var backupDir = Path.Combine(Path.GetTempPath(), "alikhlas_backups");
        var fullPath = Path.Combine(backupDir, fileName);

        if (!System.IO.File.Exists(fullPath))
            return NotFound(new { message = "الملف غير موجود" });

        var bytes = System.IO.File.ReadAllBytes(fullPath);
        return File(bytes, "application/sql", fileName);
    }
}
