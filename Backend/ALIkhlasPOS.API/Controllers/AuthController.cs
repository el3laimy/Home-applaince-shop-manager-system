using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
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
        var refreshToken = GenerateRefreshToken();

        var refreshTokenEntity = new RefreshToken
        {
            Token = refreshToken,
            Expires = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenExpiryDays"] ?? "7")),
            UserId = user.Id
        };

        _dbContext.RefreshTokens.Add(refreshTokenEntity);
        await _dbContext.SaveChangesAsync();

        return Ok(new
        {
            Token = token,
            RefreshToken = refreshToken,
            User = new { user.Id, user.Username, user.FullName, user.Role }
        });
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        var principal = GetPrincipalFromExpiredToken(request.Token);
        if (principal == null)
            return Unauthorized(new { message = "Invalid access token." });

        var username = principal.Identity?.Name ?? principal.FindFirstValue(ClaimTypes.Name);
        if (string.IsNullOrEmpty(username))
            return Unauthorized(new { message = "Invalid token claims." });

        var user = await _dbContext.Users.FirstOrDefaultAsync(u => u.Username == username);
        if (user == null || !user.IsActive)
            return Unauthorized(new { message = "User not found or inactive." });

        var refreshTokenEntity = await _dbContext.RefreshTokens
            .FirstOrDefaultAsync(t => t.Token == request.RefreshToken && t.UserId == user.Id);

        if (refreshTokenEntity == null || !refreshTokenEntity.IsActive)
            return Unauthorized(new { message = "Invalid or expired refresh token." });

        // Revoke the old token
        refreshTokenEntity.Revoked = DateTime.UtcNow;

        // Generate new tokens
        var newJwtToken = GenerateJwtToken(user);
        var newRefreshToken = GenerateRefreshToken();

        var newRefreshTokenEntity = new RefreshToken
        {
            Token = newRefreshToken,
            Expires = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenExpiryDays"] ?? "7")),
            UserId = user.Id
        };

        _dbContext.RefreshTokens.Add(newRefreshTokenEntity);
        await _dbContext.SaveChangesAsync();

        return Ok(new
        {
            Token = newJwtToken,
            RefreshToken = newRefreshToken
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
        var key = _config["Jwt:Key"];
        if (string.IsNullOrEmpty(key)) throw new InvalidOperationException("JWT Secret Key is missing from configuration.");
        
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.Name, user.Username),
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Sub, user.Username),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim("uid", user.Id.ToString()),
            new Claim(ClaimTypes.Role, user.Role),
            new Claim("FullName", user.FullName)
        };

        var expiryMinutes = double.Parse(_config["Jwt:ExpiryMinutes"] ?? "30");

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expiryMinutes),
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static string GenerateRefreshToken()
    {
        var randomNumber = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomNumber);
        return Convert.ToBase64String(randomNumber);
    }

    private ClaimsPrincipal? GetPrincipalFromExpiredToken(string token)
    {
        var key = _config["Jwt:Key"];
        if (string.IsNullOrEmpty(key)) return null;

        var tokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = false,
            ValidateIssuer = false,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
            ValidateLifetime = false // Here we are saying that we don't care about the token's expiration date
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var principal = tokenHandler.ValidateToken(token, tokenValidationParameters, out SecurityToken securityToken);
        var jwtSecurityToken = securityToken as JwtSecurityToken;

        if (jwtSecurityToken == null || !jwtSecurityToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256, StringComparison.InvariantCultureIgnoreCase))
            throw new SecurityTokenException("Invalid token");

        return principal;
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

public class RefreshTokenRequest
{
    public string Token { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
