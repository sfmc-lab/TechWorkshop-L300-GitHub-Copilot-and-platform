using System.Text;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly HttpClient _httpClient;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger, IHttpClientFactory httpClientFactory)
        {
            _configuration = configuration;
            _logger = logger;
            _httpClient = httpClientFactory.CreateClient();
        }

        public async Task<string> SendMessageAsync(string userMessage)
        {
            try
            {
                var endpoint = _configuration["Phi4:Endpoint"];
                var deploymentName = _configuration["Phi4:DeploymentName"];

                if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(deploymentName))
                {
                    _logger.LogError("Phi4 endpoint configuration is missing");
                    return "Error: Chat service is not properly configured. Please check Phi4:Endpoint and Phi4:DeploymentName settings.";
                }

                var requestUrl = $"{endpoint.TrimEnd('/')}/openai/deployments/{deploymentName}/chat/completions?api-version=2024-08-01-preview";

                // Get access token using managed identity
                var credential = new DefaultAzureCredential();
                var tokenRequestContext = new TokenRequestContext(new[] { "https://cognitiveservices.azure.com/.default" });
                var accessToken = await credential.GetTokenAsync(tokenRequestContext);

                var requestBody = new
                {
                    messages = new[]
                    {
                        new { role = "system", content = "You are a helpful assistant for Zava Storefront. Help customers with product inquiries and general questions." },
                        new { role = "user", content = userMessage }
                    },
                    max_tokens = 800,
                    temperature = 0.7
                };

                var jsonContent = JsonSerializer.Serialize(requestBody);
                var httpContent = new StringContent(jsonContent, Encoding.UTF8, "application/json");

                using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
                request.Headers.Add("Authorization", $"Bearer {accessToken.Token}");
                request.Content = httpContent;

                _logger.LogInformation("Sending message to Phi4 endpoint: {Endpoint}", requestUrl);

                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogError("Phi4 API request failed with status {StatusCode}: {Response}", response.StatusCode, responseContent);
                    return $"Error: Unable to get response from chat service (Status: {response.StatusCode})";
                }

                var jsonResponse = JsonDocument.Parse(responseContent);
                var assistantMessage = jsonResponse.RootElement
                    .GetProperty("choices")[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString();

                return assistantMessage ?? "No response received.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calling Phi4 endpoint");
                return $"Error: {ex.Message}";
            }
        }
    }
}
