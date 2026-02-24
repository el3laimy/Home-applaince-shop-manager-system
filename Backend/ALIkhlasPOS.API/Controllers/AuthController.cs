using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IConfiguration _config;

    public AuthController(ApplicationDbContext dbContext, IConfiguration config)
    {
        _dbContext = dbContext;
        _config = config;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Username == request.Username);

        if (user == null || !VerifyPassword(request.Password, user.PasswordHash))
            return Unauthorized(new { message = "اسم المستخدم أو كلمة المرور غير صحيحة" });

        if (!user.IsActive)
            return StatusCode(403, new { message = "الحساب موقوف، يرجى مراجعة المسؤول." });

        // ── Auto-upgrade legacy plaintext passwords to BCrypt on first successful login ──
        if (!user.PasswordHash.StartsWith("$2"))
        {
            user.PasswordHash = HashPassword(request.Password);
            await _dbContext.SaveChangesAsync();
        }

        var token = GenerateJwtToken(user);

        return Ok(new
        {
            Token = token,
            User = new { user.Id, user.Username, user.FullName, user.Role }
        });
    }

    /// <summary>
    /// Allows an authenticated user to change their own password.
    /// </summary>
    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var user = await _dbContext.Users.FindAsync(Guid.Parse(userId));
        if (user == null) return NotFound();

        if (!VerifyPassword(request.CurrentPassword, user.PasswordHash))
            return BadRequest(new { message = "كلمة المرور الحالية غير صحيحة." });

        user.PasswordHash = HashPassword(request.NewPassword);
        await _dbContext.SaveChangesAsync();

        return Ok(new { message = "تم تغيير كلمة المرور بنجاح." });
    }

    /// <summary>
    /// Returns the profile of the currently authenticated user.
    /// </summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> GetProfile()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId == null) return Unauthorized();

        var user = await _dbContext.Users.FindAsync(Guid.Parse(userId));
        if (user == null) return NotFound();

        return Ok(new { user.Id, user.Username, user.FullName, user.Role });
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────

    private string GenerateJwtToken(User user)
    {
        var key = _config["Jwt:Key"] ?? "super_secret_key_which_should_be_long_enough_for_hmac_sha256";
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Username),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Role, user.Role),
            new Claim(ClaimTypes.Name, user.FullName)
        };

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"] ?? "ALIkhlasPOS",
            audience: _config["Jwt:Audience"] ?? "ALIkhlasClient",
            claims: claims,
            expires: DateTime.UtcNow.AddDays(7),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>Hashes a plaintext password using BCrypt (work factor 12).</summary>
    public static string HashPassword(string plainText) =>
        BCrypt.Net.BCrypt.HashPassword(plainText, workFactor: 12);

    /// <summary>
    /// Verifies a password against its stored hash.
    /// Handles both BCrypt hashes (starting with $2) and legacy plaintext
    /// to allow a graceful migration path.
    /// </summary>
    private static bool VerifyPassword(string input, string hash)
    {
        if (hash.StartsWith("$2"))
            return BCrypt.Net.BCrypt.Verify(input, hash);

        // Legacy plaintext comparison (only until auto-upgrade kicks in on login)
        return input == hash;
    }
}

public class LoginRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
