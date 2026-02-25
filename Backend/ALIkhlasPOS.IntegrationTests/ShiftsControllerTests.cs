using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace ALIkhlasPOS.IntegrationTests
{
    public class ShiftsControllerTests : IClassFixture<CustomWebApplicationFactory>
    {
        private readonly HttpClient _client;

        public ShiftsControllerTests(CustomWebApplicationFactory factory)
        {
            _client = factory.CreateClient();
        }
        
        private async Task AuthenticateClientAsync()
        {
            var loginRequest = new { Username = "admin", Password = "admin123" };
            var response = await _client.PostAsJsonAsync("/api/auth/login", loginRequest);
            var result = await response.Content.ReadFromJsonAsync<AuthControllerTests.LoginResponse>();
            if (result?.Token != null)
            {
                _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", result.Token);
            }
        }

        private async Task EnsureNoActiveShiftAsync()
        {
            await AuthenticateClientAsync();
            var response = await _client.GetAsync("/api/shifts/current");
            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                if (content.Contains("\"hasActiveShift\":true"))
                {
                    await _client.PostAsJsonAsync("/api/shifts/close", new { ActualCash = 0, Notes = "Test cleanup" });
                }
            }
        }

        [Fact]
        public async Task OpenShift_WhenNoActiveShift_CreatesNewShift()
        {
            // Arrange
            await EnsureNoActiveShiftAsync();
            var openRequest = new { OpeningCash = 1500.50m };

            // Act
            var response = await _client.PostAsJsonAsync("/api/shifts/open", openRequest);

            // Assert
            response.EnsureSuccessStatusCode();
            var result = await response.Content.ReadFromJsonAsync<ShiftResponseWrapper>();
            
            Assert.NotNull(result?.Shift);
            Assert.Equal(1500.50m, result.Shift.OpeningCash);
            Assert.Equal(0, result.Shift.Status); // 0 = Open
        }

        [Fact]
        public async Task OpenShift_WhenShiftAlreadyOpen_ReturnsBadRequest()
        {
            // Arrange
            await AuthenticateClientAsync();
            var openRequest = new { OpeningCash = 1000m };
            await _client.PostAsJsonAsync("/api/shifts/open", openRequest); // Open first shift

            // Act
            var secondResponse = await _client.PostAsJsonAsync("/api/shifts/open", openRequest);

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, secondResponse.StatusCode);
        }

        public class ShiftResponseWrapper
        {
            public string Message { get; set; } = string.Empty;
            public ShiftDto? Shift { get; set; }
        }

        public class ShiftDto
        {
            public Guid Id { get; set; }
            public decimal OpeningCash { get; set; }
            public int Status { get; set; }
        }
    }
}
