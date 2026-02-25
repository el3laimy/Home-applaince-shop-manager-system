using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Testcontainers.PostgreSql;
using Xunit;

namespace ALIkhlasPOS.IntegrationTests
{
    public class CustomWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime
    {
        private readonly PostgreSqlContainer _dbContainer;

        public CustomWebApplicationFactory()
        {
            _dbContainer = new PostgreSqlBuilder()
                .WithImage("postgres:15-alpine")
                .WithDatabase("testdb")
                .WithUsername("postgres")
                .WithPassword("postgres")
                .Build();
        }

        public async Task InitializeAsync()
        {
            await _dbContainer.StartAsync();
        }

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            
            // Set environment variables for tests
            Environment.SetEnvironmentVariable("Jwt__Key", "SuperSecretTestingKey12345678901234567890");
            Environment.SetEnvironmentVariable("Jwt__Issuer", "TestIssuer");
            Environment.SetEnvironmentVariable("Jwt__Audience", "TestAudience");
            Environment.SetEnvironmentVariable("Jwt__ExpiryMinutes", "30");
            
            builder.ConfigureServices(services =>
            {
                // Remove existing DbContext configuration
                services.RemoveAll(typeof(DbContextOptions<ApplicationDbContext>));
                services.RemoveAll(typeof(ApplicationDbContext));

                // Add DbContext using Testcontainer
                services.AddDbContext<ApplicationDbContext>(options =>
                {
                    options.UseNpgsql(_dbContainer.GetConnectionString());
                });

                // Apply migrations to test DB
                var sp = services.BuildServiceProvider();
                using var scope = sp.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                db.Database.Migrate(); // This ensures the schema is identical to production

                // Seed test admin user
                if (!db.Users.Any())
                {
                    db.Users.Add(new Domain.Entities.User
                    {
                        Username = "admin",
                        PasswordHash = API.Controllers.AuthController.HashPassword("admin123"),
                        FullName = "مدير النظام الأساسي",
                        Role = "Admin",
                        IsActive = true
                    });
                    db.SaveChanges();
                }

                // Mock Redis or use a real inner-process one for tests if needed. For now, we can just let it fail or provide a local connection string if testcontainers redis is desired.
                // Assuming tests don't strictly require a real redis cluster, or we can use a MemoryDistributedCache.
                services.RemoveAll(typeof(Microsoft.Extensions.Caching.Distributed.IDistributedCache));
                services.AddDistributedMemoryCache();
                
                // Remove Background Workers
                services.RemoveAll(typeof(Microsoft.Extensions.Hosting.IHostedService));
            });
        }

        public new async Task DisposeAsync()
        {
            await _dbContainer.DisposeAsync();
        }
    }
}
