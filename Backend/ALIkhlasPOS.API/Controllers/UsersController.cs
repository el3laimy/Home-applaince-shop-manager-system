using System;
using System.Linq;
using System.Threading.Tasks;
using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Domain.Entities;
using ALIkhlasPOS.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly ApplicationDbContext _dbContext;
    private readonly IPasswordService _passwordService;

    public UsersController(ApplicationDbContext dbContext, IPasswordService passwordService)
    {
        _dbContext = dbContext;
        _passwordService = passwordService;
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────

    public record CreateUserRequest(
        string Username,
        string FullName,
        string Password,
        string Role = "Cashier"
    );

    public record UpdateUserRequest(
        string FullName,
        string Role
    );

    // ── GET /api/users — List all (Admin only) ────────────────────────────────
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(CancellationToken ct)
    {
        var users = await _dbContext.Users
            .OrderBy(u => u.FullName)
            .Select(u => new
            {
                u.Id,
                u.Username,
                u.FullName,
                u.Role,
                u.IsActive,
                PasswordSet = !string.IsNullOrEmpty(u.PasswordHash)
            })
            .ToListAsync(ct);

        return Ok(users);
    }

    // ── GET /api/users/{id} ───────────────────────────────────────────────────
    [HttpGet("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken ct)
    {
        var user = await _dbContext.Users.FindAsync(new object[] { id }, ct);
        if (user == null) return NotFound();
        return Ok(new { user.Id, user.Username, user.FullName, user.Role, user.IsActive });
    }

    // ── POST /api/users — Create user (Admin only) ────────────────────────────
    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest req, CancellationToken ct)
    {
        if (await _dbContext.Users.AnyAsync(u => u.Username == req.Username, ct))
            return Conflict(new { message = $"اسم المستخدم '{req.Username}' مستخدم بالفعل." });

        if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 6)
            return BadRequest(new { message = "كلمة المرور يجب أن تكون 6 أحرف على الأقل." });

        var allowedRoles = new[] { "Admin", "Manager", "Cashier" };
        if (!allowedRoles.Contains(req.Role))
            return BadRequest(new { message = $"الدور '{req.Role}' غير مدعوم. يجب أن يكون أحد: {string.Join(", ", allowedRoles)}" });

        var user = new User
        {
            Username = req.Username.Trim(),
            FullName = req.FullName.Trim(),
            PasswordHash = _passwordService.HashPassword(req.Password),
            Role = req.Role,
            IsActive = true
        };

        _dbContext.Users.Add(user);
        await _dbContext.SaveChangesAsync(ct);

        return CreatedAtAction(nameof(GetById), new { id = user.Id },
            new { user.Id, user.Username, user.FullName, user.Role, user.IsActive });
    }

    // ── PUT /api/users/{id} — Update name & role ─────────────────────────────
    [HttpPut("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdateUserRequest req, CancellationToken ct)
    {
        var user = await _dbContext.Users.FindAsync(new object[] { id }, ct);
        if (user == null) return NotFound();

        user.FullName = req.FullName.Trim();
        user.Role = req.Role;
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new { user.Id, user.FullName, user.Role });
    }

    // ── POST /api/users/{id}/reset-password — Admin reset another user's password
    [HttpPost("{id:guid}/reset-password")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ResetPassword(Guid id, [FromBody] ResetPasswordRequest req, CancellationToken ct)
    {
        var user = await _dbContext.Users.FindAsync(new object[] { id }, ct);
        if (user == null) return NotFound();

        if (string.IsNullOrWhiteSpace(req.NewPassword) || req.NewPassword.Length < 6)
            return BadRequest(new { message = "كلمة المرور يجب أن تكون 6 أحرف على الأقل." });

        user.PasswordHash = _passwordService.HashPassword(req.NewPassword);
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new { message = "تم إعادة تعيين كلمة المرور بنجاح." });
    }

    // ── PATCH /api/users/{id}/toggle-active ──────────────────────────────────
    [HttpPatch("{id:guid}/toggle-active")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ToggleActive(Guid id, CancellationToken ct)
    {
        var user = await _dbContext.Users.FindAsync(new object[] { id }, ct);
        if (user == null) return NotFound();

        // Prevent deactivating the last active Admin
        if (user.IsActive && user.Role == "Admin")
        {
            var activeAdminCount = await _dbContext.Users
                .CountAsync(u => u.Role == "Admin" && u.IsActive, ct);
            if (activeAdminCount <= 1)
                return BadRequest(new { message = "لا يمكن تعطيل آخر مدير نشط في النظام." });
        }

        user.IsActive = !user.IsActive;
        await _dbContext.SaveChangesAsync(ct);

        return Ok(new { user.Id, user.IsActive, message = user.IsActive ? "تم تفعيل الحساب" : "تم تعطيل الحساب" });
    }

    // ── DELETE /api/users/{id} ────────────────────────────────────────────────
    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var user = await _dbContext.Users.FindAsync(new object[] { id }, ct);
        if (user == null) return NotFound();

        // Safety: prevent deleting the last Admin
        if (user.Role == "Admin")
        {
            var adminCount = await _dbContext.Users.CountAsync(u => u.Role == "Admin", ct);
            if (adminCount <= 1)
                return BadRequest(new { message = "لا يمكن حذف آخر مدير في النظام." });
        }

        _dbContext.Users.Remove(user);
        await _dbContext.SaveChangesAsync(ct);
        return NoContent();
    }
}

public record ResetPasswordRequest(string NewPassword);
