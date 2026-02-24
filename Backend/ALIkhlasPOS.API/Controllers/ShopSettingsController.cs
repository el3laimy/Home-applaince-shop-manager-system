using System;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ShopSettingsController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;

    public ShopSettingsController(ApplicationDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    /// <summary>Returns the current shop settings (singleton).</summary>
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var settings = await _dbContext.ShopSettings.FirstOrDefaultAsync(ct);
        if (settings == null)
        {
            // Create default settings on first run
            settings = new ShopSettings { ShopName = "نظام إخلاص POS" };
            _dbContext.ShopSettings.Add(settings);
            await _dbContext.SaveChangesAsync(ct);
        }
        return Ok(settings);
    }

    /// <summary>Updates or creates the shop settings.</summary>
    [HttpPut]
    [Authorize(Roles = "Admin,Manager")]
    public async Task<IActionResult> Update([FromBody] ShopSettings updated, CancellationToken ct)
    {
        var settings = await _dbContext.ShopSettings.FirstOrDefaultAsync(ct);
        if (settings == null)
        {
            updated.Id = Guid.NewGuid();
            _dbContext.ShopSettings.Add(updated);
        }
        else
        {
            settings.ShopName = updated.ShopName;
            settings.Address = updated.Address;
            settings.Phone = updated.Phone;
            settings.Phone2 = updated.Phone2;
            settings.CommercialRegNo = updated.CommercialRegNo;
            settings.TaxNumber = updated.TaxNumber;
            settings.LogoBase64 = updated.LogoBase64;
            settings.ReceiptFooter = updated.ReceiptFooter;
            settings.VatEnabled = updated.VatEnabled;
            settings.DefaultVatRate = updated.DefaultVatRate;
            settings.CurrencySymbol = updated.CurrencySymbol;
            settings.CurrencyCode = updated.CurrencyCode;
            settings.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync(ct);
        return Ok(settings);
    }
}
