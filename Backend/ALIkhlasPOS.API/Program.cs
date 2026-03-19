using System.Text;
using System.Threading.RateLimiting;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Services;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Infrastructure.Services;
using ALIkhlasPOS.API.Middleware;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
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
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.IInvoiceService, ALIkhlasPOS.Application.Services.InvoiceService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.IPurchaseService, ALIkhlasPOS.Application.Services.PurchaseService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.IReturnInvoiceService, ALIkhlasPOS.Application.Services.ReturnInvoiceService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.ISystemAccountService, ALIkhlasPOS.Infrastructure.Services.SystemAccountService>();
builder.Services.AddScoped<IPasswordService, PasswordService>();
builder.Services.AddScoped<IBarcodeService, BarcodeService>();
builder.Services.AddScoped<IProductCacheService, ProductCacheService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Services.InvoicePdfGenerator>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.IInstallmentService, ALIkhlasPOS.Infrastructure.Services.InstallmentService>();
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.IProductService, ALIkhlasPOS.Infrastructure.Services.ProductService>();

// BUG-07: SMS factory and named HttpClient for VictoryLink / Twilio / Unifonic
builder.Services.AddHttpClient("SmsClient")
    .ConfigureHttpClient(c => c.Timeout = TimeSpan.FromSeconds(10));
builder.Services.AddSingleton<ALIkhlasPOS.Infrastructure.Sms.SmsServiceFactory>();


// Register Background Workers
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.InstallmentReminderService>();
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.DatabaseBackupService>();
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.AutoCloseShiftService>();

// Learn more about configuring OpenAPI
builder.Services.AddOpenApi();
builder.Services.AddSignalR();
builder.Services.AddHealthChecks();

// ── CORS Policy (Restricted to local origins) ────────────────────────────
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
                  "http://localhost:5291",
                  "https://localhost:5291",
                  "http://127.0.0.1:5291",
                  "http://localhost:3000",   // Flutter web dev
                  "http://localhost:8080"    // Flutter web alt
              )
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// ── Rate Limiting ─────────────────────────────────────────────────────────
builder.Services.AddRateLimiter(options =>
{
    // Login: max 5 attempts per minute per IP
    options.AddFixedWindowLimiter("login", opt =>
    {
        opt.PermitLimit = 5;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueLimit = 0;
    });
    // Financial endpoints: max 30 requests per minute per IP
    options.AddFixedWindowLimiter("financial", opt =>
    {
        opt.PermitLimit = 30;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueLimit = 2;
    });
    // General API: max 120 requests per minute per IP
    options.AddFixedWindowLimiter("general", opt =>
    {
        opt.PermitLimit = 120;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueLimit = 5;
    });
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseSerilogRequestLogging();

// ── Security Headers ──────────────────────────────────────────────────────
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    // Prevent caching of API responses (JSON data)
    if (context.Request.Path.StartsWithSegments("/api"))
    {
        context.Response.Headers["Cache-Control"] = "no-store, no-cache";
        context.Response.Headers["Pragma"] = "no-cache";
    }
    await next();
});

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
        var seedPasswordService = scope.ServiceProvider.GetRequiredService<IPasswordService>();
        db.Users.Add(new User
        {
            Username = "admin",
            PasswordHash = seedPasswordService.HashPassword("admin123"),
            FullName = "مدير النظام الأساسي",
            Role = "Admin",
            IsActive = true
        });
        db.SaveChanges();
    }

    // Seed the foundational Chart of Accounts for the ERP
    await ALIkhlasPOS.Infrastructure.Data.AccountSeeder.SeedChartOfAccountsAsync(scope.ServiceProvider);
    
    // Optional: Preload Cache on Startup
    var cacheService = scope.ServiceProvider.GetRequiredService<IProductCacheService>();
    await cacheService.PreloadValidProductsAsync();
}

app.UseHttpsRedirection();

// Enable CORS
app.UseCors();

// Enable Rate Limiting
app.UseRateLimiter();

// Serve static files (product images stored in wwwroot/uploads/)
app.UseStaticFiles();

// Add Authentication before Authorization
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ALIkhlasPOS.API.Hubs.DashboardHub>("/hubs/dashboard");
app.MapHealthChecks("/health");

app.Run();

public partial class Program { }
