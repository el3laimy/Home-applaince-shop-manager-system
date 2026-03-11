using System.Text;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Services;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Infrastructure.Services;
using ALIkhlasPOS.API.Middleware;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
builder.Host.UseSerilog((context, services, configuration) => configuration
    .ReadFrom.Configuration(context.Configuration)
    .ReadFrom.Services(services)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/alikhlaspos-.txt", rollingInterval: RollingInterval.Day));

// Add services to the container.
builder.Services.AddControllers();

// Add DbContext
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
    
builder.Services.AddScoped<DbContext>(provider => provider.GetRequiredService<ApplicationDbContext>());

// Configure Redis Distributed Cache
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("RedisConnection");
    options.InstanceName = "ALIkhlasPOS_";
});

// Verify JWT Key exists to fail-fast
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrEmpty(jwtKey))
{
    throw new InvalidOperationException("JWT Secret Key is missing from configuration.");
}

// Configure JWT Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.Zero
        };
    });
builder.Services.AddAuthorization();

// Register Domain & Infrastructure Services
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.Accounting.IAccountingService, ALIkhlasPOS.Application.Services.Accounting.AccountingService>();
builder.Services.AddScoped<IBarcodeService, BarcodeService>();
builder.Services.AddScoped<IProductCacheService, ProductCacheService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Services.InvoicePdfGenerator>();

// BUG-07: SMS factory and named HttpClient for VictoryLink / Twilio / Unifonic
builder.Services.AddHttpClient("SmsClient")
    .ConfigureHttpClient(c => c.Timeout = TimeSpan.FromSeconds(10));
builder.Services.AddSingleton<ALIkhlasPOS.Infrastructure.Sms.SmsServiceFactory>();


// Register Background Workers
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.InstallmentReminderService>();
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.DatabaseBackupService>();

// Learn more about configuring OpenAPI
builder.Services.AddOpenApi();
builder.Services.AddSignalR();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseSerilogRequestLogging();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    
    // Auto-apply migrations and Preload Redis Cache in development
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    db.Database.Migrate();
    
    // Seed default admin user if none exists (password hashed with BCrypt)
    if (!db.Users.Any())
    {
        db.Users.Add(new User
        {
            Username = "admin",
            PasswordHash = ALIkhlasPOS.API.Controllers.AuthController.HashPassword("admin123"),
            FullName = "مدير النظام الأساسي",
            Role = "Admin",
            IsActive = true
        });
        db.SaveChanges();
    }
    
    // Optional: Preload Cache on Startup
    var cacheService = scope.ServiceProvider.GetRequiredService<IProductCacheService>();
    await cacheService.PreloadValidProductsAsync();
}

app.UseHttpsRedirection();

// Serve static files (product images stored in wwwroot/uploads/)
app.UseStaticFiles();

// Add Authentication before Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ALIkhlasPOS.API.Hubs.DashboardHub>("/hubs/dashboard");

app.Run();

public partial class Program { }
