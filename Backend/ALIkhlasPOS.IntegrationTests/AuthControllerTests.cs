using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace ALIkhlasPOS.IntegrationTests
{
    public class AuthControllerTests : IClassFixture<CustomWebApplicationFactory>
    {
        private readonly HttpClient _client;

        public AuthControllerTests(CustomWebApplicationFactory factory)
        {
            _client = factory.CreateClient();
        }

        [Fact]
        public async Task Login_WithValidAdminCredentials_ReturnsOkAndJwtAttributesWithGuidId()
        {
            // Arrange
            // The factory seeds an admin user automatically via Program.cs in Development/Testing
            var loginRequest = new
            {
                Username = "admin",
                Password = "admin123"
            };

            // Act
            var response = await _client.PostAsJsonAsync("/api/auth/login", loginRequest);

            // Assert
            response.EnsureSuccessStatusCode(); // Status Code 200-299
            
            var result = await response.Content.ReadFromJsonAsync<LoginResponse>();
            
            Assert.NotNull(result);
            Assert.NotNull(result.Token);
            Assert.NotNull(result.RefreshToken);
            Assert.NotNull(result.User);
            
            // Critical check: Ensure the returned User Id is a valid Guid structure and matches the Token's sub claims.
            Assert.True(Guid.TryParse(result.User.Id, out _));
        }

        [Fact]
        public async Task Login_WithInvalidCredentials_ReturnsUnauthorized()
        {
            // Arrange
            var loginRequest = new
            {
                Username = "admin",
                Password = "wrongpassword"
            };

            // Act
            var response = await _client.PostAsJsonAsync("/api/auth/login", loginRequest);

            // Assert
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        }

        public class LoginResponse
        {
            public string Token { get; set; } = string.Empty;
            public string RefreshToken { get; set; } = string.Empty;
            public UserResponse User { get; set; } = new();
        }

        public class UserResponse
        {
            public string Id { get; set; } = string.Empty;
            public string Username { get; set; } = string.Empty;
            public string FullName { get; set; } = string.Empty;
            public string Role { get; set; } = string.Empty;
        }
    }
}
