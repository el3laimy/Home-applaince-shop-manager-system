using System.Text;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Services;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using ALIkhlasPOS.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

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
            ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "ALIkhlasPOS",
            ValidAudience = builder.Configuration["Jwt:Audience"] ?? "ALIkhlasClient",
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? "super_secret_key_which_should_be_long_enough_for_hmac_sha256"))
        };
    });
builder.Services.AddAuthorization();

// Register Domain & Infrastructure Services
builder.Services.AddScoped<ALIkhlasPOS.Application.Interfaces.Accounting.IAccountingService, ALIkhlasPOS.Application.Services.Accounting.AccountingService>();
builder.Services.AddScoped<IBarcodeService, BarcodeService>();
builder.Services.AddScoped<IProductCacheService, ProductCacheService>();

// Register Background Workers
builder.Services.AddHostedService<ALIkhlasPOS.API.Workers.InstallmentReminderService>();

// Learn more about configuring OpenAPI
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
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

app.Run();
