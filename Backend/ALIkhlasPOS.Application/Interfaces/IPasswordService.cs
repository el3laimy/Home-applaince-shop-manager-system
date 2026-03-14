namespace ALIkhlasPOS.Application.Interfaces;

/// <summary>
/// Centralized password hashing and verification service.
/// This replaces the static methods previously embedded in AuthController.
/// </summary>
public interface IPasswordService
{
    /// <summary>Hashes a plaintext password using BCrypt (work factor 12).</summary>
    string HashPassword(string plainText);

    /// <summary>
    /// Verifies a password against its stored BCrypt hash.
    /// Returns false for any non-BCrypt hash (legacy plaintext passwords are no longer supported).
    /// </summary>
    bool VerifyPassword(string input, string storedHash);
}
