using ALIkhlasPOS.Application.Interfaces;
using ALIkhlasPOS.Application.Services;
using Xunit;

namespace ALIkhlasPOS.IntegrationTests;

public class PasswordServiceTests
{
    private readonly IPasswordService _sut = new PasswordService();

    [Fact]
    public void HashPassword_ReturnsNonEmptyHash()
    {
        // Act
        var hash = _sut.HashPassword("testPassword123");

        // Assert
        Assert.NotNull(hash);
        Assert.NotEmpty(hash);
        Assert.StartsWith("$2", hash); // BCrypt hashes start with $2a$ or $2b$
    }

    [Fact]
    public void HashPassword_ReturnsDifferentHashesForSameInput()
    {
        // BCrypt uses random salt, so same password should produce different hashes
        var hash1 = _sut.HashPassword("samePassword");
        var hash2 = _sut.HashPassword("samePassword");

        Assert.NotEqual(hash1, hash2);
    }

    [Fact]
    public void VerifyPassword_WithCorrectPassword_ReturnsTrue()
    {
        // Arrange
        var password = "admin123";
        var hash = _sut.HashPassword(password);

        // Act
        var result = _sut.VerifyPassword(password, hash);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void VerifyPassword_WithWrongPassword_ReturnsFalse()
    {
        // Arrange
        var hash = _sut.HashPassword("correctPassword");

        // Act
        var result = _sut.VerifyPassword("wrongPassword", hash);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void VerifyPassword_WithPlaintextHash_ReturnsFalse()
    {
        // Plaintext passwords should NOT verify — this is the security fix
        var result = _sut.VerifyPassword("admin123", "admin123");

        Assert.False(result);
    }

    [Fact]
    public void VerifyPassword_WithEmptyPassword_ReturnsFalse()
    {
        var hash = _sut.HashPassword("somePassword");
        var result = _sut.VerifyPassword("", hash);

        Assert.False(result);
    }

    [Fact]
    public void VerifyPassword_WithEmptyHash_ReturnsFalse()
    {
        var result = _sut.VerifyPassword("somePassword", "");

        Assert.False(result);
    }

    [Fact]
    public void HashPassword_WithUnicodeCharacters_Works()
    {
        // Arabic characters in password
        var password = "كلمة_مرور_آمنة_123";
        var hash = _sut.HashPassword(password);

        Assert.True(_sut.VerifyPassword(password, hash));
    }

    [Fact]
    public void HashPassword_WithLongPassword_Works()
    {
        // BCrypt handles up to 72 bytes — test with a long password
        var password = new string('A', 100);
        var hash = _sut.HashPassword(password);

        Assert.True(_sut.VerifyPassword(password, hash));
    }
}
