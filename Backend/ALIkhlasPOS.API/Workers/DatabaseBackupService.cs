using System.Diagnostics;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace ALIkhlasPOS.API.Workers;

public class DatabaseBackupService : BackgroundService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<DatabaseBackupService> _logger;
    private readonly string _defaultBackupFolder;
    private readonly IServiceScopeFactory _scopeFactory;

    public DatabaseBackupService(IConfiguration configuration, ILogger<DatabaseBackupService> logger, IServiceScopeFactory scopeFactory)
    {
        _configuration = configuration;
        _logger = logger;
        _scopeFactory = scopeFactory;
        _defaultBackupFolder = Path.Combine(Directory.GetCurrentDirectory(), "Backups");
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Database Backup Service is starting.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Run backup daily at 2:00 AM
                var now = DateTime.Now;
                var nextRun = new DateTime(now.Year, now.Month, now.Day, 2, 0, 0);
                if (now > nextRun)
                {
                    nextRun = nextRun.AddDays(1);
                }

                var delay = nextRun - now;
                _logger.LogInformation($"Next database backup scheduled in {delay.TotalHours:F2} hours (at {nextRun}).");

                await Task.Delay(delay, stoppingToken);

                if (!stoppingToken.IsCancellationRequested)
                {
                    PerformBackup();
                }
            }
            catch (TaskCanceledException)
            {
                // Expected when stopping
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while executing database backup.");
                // Retry in 1 hour if failed
                await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
            }
        }
    }

    private void PerformBackup()
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ALIkhlasPOS.Infrastructure.Data.ApplicationDbContext>();
            
            var settings = dbContext.ShopSettings.FirstOrDefault();
            var backupDir = !string.IsNullOrWhiteSpace(settings?.BackupPath) 
                ? settings.BackupPath 
                : _defaultBackupFolder;

            if (!Directory.Exists(backupDir))
            {
                Directory.CreateDirectory(backupDir);
            }

            var connString = _configuration.GetConnectionString("DefaultConnection");
            if (string.IsNullOrEmpty(connString))
            {
                _logger.LogWarning("Cannot perform backup: DefaultConnection is missing.");
                return;
            }

            var builder = new NpgsqlConnectionStringBuilder(connString);
            string host = builder.Host ?? "localhost";
            string username = builder.Username ?? "";
            string password = builder.Password ?? "";
            string database = builder.Database ?? "";
            string port = builder.Port.ToString();

            string timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            string backupFileName = $"backup_{database}_{timestamp}.sql";
            string backupPath = Path.Combine(backupDir, backupFileName);

            _logger.LogInformation($"Starting database backup for {database} to {backupPath}");

            // Use docker to run pg_dump since postgres is in a container
            var tmpFileName = $"/tmp/{backupFileName}";
            var processStartInfo = new ProcessStartInfo
            {
                FileName = "docker",
                Arguments = $"exec -e PGPASSWORD={password} alikhlaspos-postgres pg_dump -h {host} -p {port} -U {username} -F p -c -f \"{tmpFileName}\" {database}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (var process = Process.Start(processStartInfo))
            {
                if (process == null)
                {
                    _logger.LogError("Failed to start docker exec pg_dump process.");
                    return;
                }

                process.WaitForExit();

                if (process.ExitCode == 0)
                {
                    // Copy file from container
                    var copyStartInfo = new ProcessStartInfo
                    {
                        FileName = "docker",
                        Arguments = $"cp alikhlaspos-postgres:{tmpFileName} \"{backupPath}\"",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    using var copyProcess = Process.Start(copyStartInfo);
                    copyProcess?.WaitForExit();

                    // Remove file from container
                    var rmStartInfo = new ProcessStartInfo
                    {
                        FileName = "docker",
                        Arguments = $"exec alikhlaspos-postgres rm \"{tmpFileName}\"",
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };
                    using var rmProcess = Process.Start(rmStartInfo);
                    rmProcess?.WaitForExit();

                    _logger.LogInformation($"Database backup completed successfully: {backupPath}");
                    CleanOldBackups();
                }
                else
                {
                    string error = process.StandardError.ReadToEnd();
                    _logger.LogError($"Database backup failed with exit code {process.ExitCode}. Error: {error}");
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Exception during backup process.");
        }
    }

    private void CleanOldBackups()
    {
        try
        {
            var directoryInfo = new DirectoryInfo(_backupFolder);
            var files = directoryInfo.GetFiles("backup_*.sql")
                                     .OrderByDescending(f => f.CreationTime)
                                     .ToList();

            // Keep the latest 7 backups
            int keepCount = 7;
            if (files.Count > keepCount)
            {
                for (int i = keepCount; i < files.Count; i++)
                {
                    files[i].Delete();
                    _logger.LogInformation($"Deleted old backup file: {files[i].Name}");
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while cleaning old backups.");
        }
    }
}
