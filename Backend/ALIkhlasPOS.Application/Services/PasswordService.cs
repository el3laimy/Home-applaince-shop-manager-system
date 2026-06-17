using ALIkhlasPOS.Application.Interfaces;

namespace ALIkhlasPOS.Application.Services;

/// <summary>
/// BCrypt-based password service. Legacy plaintext passwords are no longer
/// accepted — the admin must reset them via the Users management screen.
/// </summary>
public class PasswordService : IPasswordService
{
    public string HashPassword(string plainText) =>
        BCrypt.Net.BCrypt.HashPassword(plainText, workFactor: 12);

    public bool VerifyPassword(string input, string storedHash)
    {
        // Only BCrypt hashes (starting with $2) are accepted.
        // Legacy plaintext passwords MUST be reset by admin.
        if (!storedHash.StartsWith("$2"))
            return false;

        return BCrypt.Net.BCrypt.Verify(input, storedHash);
    }
}
