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

        var settings = await _dbContext.ShopSettings.FirstOrDefaultAsync(ct);
        var backupDir = !string.IsNullOrWhiteSpace(settings?.BackupPath) 
            ? settings.BackupPath 
            : Path.Combine(Directory.GetCurrentDirectory(), "Backups");

        object lastBackup = null;
        if (Directory.Exists(backupDir))
        {
            var latestFile = new DirectoryInfo(backupDir)
                .GetFiles("*.sql")
                .OrderByDescending(f => f.CreationTime)
                .FirstOrDefault();

            if (latestFile != null)
            {
                lastBackup = new
                {
                    fileName = latestFile.Name,
                    sizeBytes = latestFile.Length,
                    createdAt = latestFile.CreationTimeUtc
                };
            }
        }

        return Ok(new
        {
            DatabaseEngine = "PostgreSQL",
            BackupMethod = "pg_dump",
            LastChecked = DateTime.UtcNow,
            TotalRecords = totalRecords,
            Tables = counts,
            LastBackup = lastBackup
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
        var settings = await _dbContext.ShopSettings.FirstOrDefaultAsync(ct);
        var backupDir = !string.IsNullOrWhiteSpace(settings?.BackupPath) 
            ? settings.BackupPath 
            : Path.Combine(Directory.GetCurrentDirectory(), "Backups");
        Directory.CreateDirectory(backupDir);

        var database = builder.Database ?? "db";
        var fileName = $"backup_{database}_{DateTime.Now:yyyyMMdd_HHmmss}.sql";
        var fullPath = Path.Combine(backupDir, fileName);

        var env = new Dictionary<string, string>
        {
            ["PGPASSWORD"] = builder.Password ?? ""
        };

        // PostgreSQL is running in docker (container name: alikhlaspos-postgres)
        var psi = new System.Diagnostics.ProcessStartInfo("docker")
        {
            Arguments = $"exec -e PGPASSWORD={builder.Password} alikhlaspos-postgres pg_dump -h {builder.Host} -p {builder.Port} -U {builder.Username} -d {builder.Database} -f /tmp/{fileName} --no-password",
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
                _logger.LogError("docker exec pg_dump failed: {Error}", stderr);
                return StatusCode(500, new { message = $"فشل النسخ الاحتياطي: {stderr}" });
            }

            // Copy the file from the container to the host
            var copyPsi = new System.Diagnostics.ProcessStartInfo("docker")
            {
                Arguments = $"cp alikhlaspos-postgres:/tmp/{fileName} {fullPath}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            };
            using var copyProcess = System.Diagnostics.Process.Start(copyPsi)!;
            await copyProcess.WaitForExitAsync(ct);

            // Clean up the file inside the container
            var rmPsi = new System.Diagnostics.ProcessStartInfo("docker")
            {
                Arguments = $"exec alikhlaspos-postgres rm /tmp/{fileName}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            };
            using var rmProcess = System.Diagnostics.Process.Start(rmPsi)!;
            await rmProcess.WaitForExitAsync(ct);

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

        var backupDir = Path.Combine(Directory.GetCurrentDirectory(), "Backups");
        var fullPath = Path.Combine(backupDir, fileName);

        if (!System.IO.File.Exists(fullPath))
            return NotFound(new { message = "الملف غير موجود" });

        var bytes = System.IO.File.ReadAllBytes(fullPath);
        return File(bytes, "application/sql", fileName);
    }
}
