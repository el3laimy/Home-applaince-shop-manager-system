using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

class Program {
    static async Task Main() {
        var client = new HttpClient();
        client.DefaultRequestHeaders.Add("User-Agent", "ALIkhlasPOS/1.0 (https://github.com/pos-system) ImageFetcher");
        
        var name = "غسالة ايديال";
        var query = Uri.EscapeDataString(name);
        
        // Use Wikipedia exact match or search
        var url = $"https://ar.wikipedia.org/w/api.php?action=query&prop=pageimages&format=json&piprop=original&titles={query}";
        
        var request = new HttpRequestMessage(HttpMethod.Get, url);
        var response = await client.SendAsync(request);
        var json = await response.Content.ReadAsStringAsync();
        
        Console.WriteLine("JSON Result:");
        Console.WriteLine(json);
        
        try {
            var doc = JsonDocument.Parse(json);
            var pages = doc.RootElement.GetProperty("query").GetProperty("pages");
            foreach (var page in pages.EnumerateObject()) {
                if (page.Value.TryGetProperty("original", out var orig)) {
                    if (orig.TryGetProperty("source", out var src)) {
                        Console.WriteLine("SUCCESS: Found " + src.GetString());
                        return;
                    }
                }
            }
        } catch {}
        
        Console.WriteLine("FAIL: No match found.");
    }
}
