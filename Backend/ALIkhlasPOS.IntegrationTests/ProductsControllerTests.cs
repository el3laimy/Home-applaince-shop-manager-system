using System.Net;
using System.Net.Http.Json;
using Xunit;

namespace ALIkhlasPOS.IntegrationTests
{
    public class ProductsControllerTests : IClassFixture<CustomWebApplicationFactory>
    {
        private readonly HttpClient _client;

        public ProductsControllerTests(CustomWebApplicationFactory factory)
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

        private static string CreateValidEan13()
        {
            var first12 = Random.Shared.NextInt64(100_000_000_000, 999_999_999_999).ToString();
            var sum = 0;

            for (var i = 0; i < first12.Length; i++)
            {
                var digit = first12[i] - '0';
                sum += i % 2 == 0 ? digit : digit * 3;
            }

            var checkDigit = (10 - (sum % 10)) % 10;
            return first12 + checkDigit;
        }

        [Fact]
        public async Task CreateProduct_WithUniqueBarcode_ReturnsCreated()
        {
            // Arrange
            await AuthenticateClientAsync();
            var uniqueBarcode = CreateValidEan13();
            var productRequest = new
            {
                Name = "Integration Test Product",
                GlobalBarcode = uniqueBarcode,
                PurchasePrice = 100m,
                Price = 150m,
                WholesalePrice = 120m,
                StockQuantity = 50,
                MinStockLevel = 10,
                CategoryName = "General"
            };

            // Act
            var response = await _client.PostAsJsonAsync("/api/products", productRequest);
            var content = await response.Content.ReadAsStringAsync();

            // Assert
            if (!response.IsSuccessStatusCode)
            {
                throw new Exception($"Failed with {(int)response.StatusCode}: {content}");
            }
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        }

        [Fact]
        public async Task CreateProduct_WithDuplicateBarcode_ReturnsBadRequest()
        {
            // Arrange
            await AuthenticateClientAsync();
            var duplicateBarcode = CreateValidEan13();
            var productRequest = new
            {
                Name = "Integration Test Product 1",
                GlobalBarcode = duplicateBarcode,
                PurchasePrice = 10m,
                Price = 15m,
                WholesalePrice = 12m,
                StockQuantity = 10,
                CategoryName = "General"
            };

            // Act
            await _client.PostAsJsonAsync("/api/products", productRequest); // First creation succeeds
            var duplicateResponse = await _client.PostAsJsonAsync("/api/products", productRequest); // Second creation fails

            // Assert
            Assert.Equal(HttpStatusCode.BadRequest, duplicateResponse.StatusCode);
        }
    }
}
