using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using ArteInFerro.Rapportini.Desktop.Models;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class SupabaseAuthService
{
    private readonly HttpClient _http;
    private readonly AppSettings _settings;
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web);

    public SupabaseAuthService(HttpClient http, AppSettings settings)
    {
        _http = http;
        _settings = settings;
    }

    public async Task<AppSession> SignInAdminAsync(
        string email,
        string password,
        CancellationToken cancellationToken = default)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_settings.SupabaseUrl.TrimEnd('/')}/auth/v1/token?grant_type=password");
        request.Headers.Add("apikey", _settings.SupabasePublishableKey);
        request.Content = JsonContent(new { email = email.Trim(), password });

        using var response = await _http.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException(ReadError(payload, "Email o password non valide."));

        var token = JsonSerializer.Deserialize<TokenResponse>(payload, _json)
            ?? throw new ApiException("Risposta di autenticazione non valida.");
        if (string.IsNullOrWhiteSpace(token.AccessToken) ||
            string.IsNullOrWhiteSpace(token.RefreshToken) ||
            token.User is null)
        {
            throw new ApiException("Sessione Supabase incompleta.");
        }

        var profile = await LoadProfileAsync(
            token.AccessToken,
            token.User.Id,
            cancellationToken);
        if (!profile.Active)
            throw new ApiException("Questo account è stato disattivato.");
        if (!string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
            throw new ApiException(
                "L’accesso al programma Windows è riservato agli amministratori.");

        return new AppSession(
            token.AccessToken,
            token.RefreshToken,
            DateTimeOffset.UtcNow.AddSeconds(token.ExpiresIn > 0 ? token.ExpiresIn : 3600),
            token.User.Id,
            profile.FullName,
            profile.Email,
            profile.Role);
    }

    private async Task<UserProfile> LoadProfileAsync(
        string token,
        string userId,
        CancellationToken cancellationToken)
    {
        var uri = $"{_settings.SupabaseUrl.TrimEnd('/')}/rest/v1/utenti" +
                  $"?id=eq.{Uri.EscapeDataString(userId)}" +
                  "&select=nome_cognome,email,ruolo,attivo";
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        AddApiHeaders(request, token);
        using var response = await _http.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException(ReadError(payload, "Impossibile leggere il profilo."));

        var profiles = JsonSerializer.Deserialize<List<UserProfile>>(payload, _json) ?? [];
        return profiles.SingleOrDefault()
            ?? throw new ApiException("Profilo applicativo non trovato.");
    }

    private void AddApiHeaders(HttpRequestMessage request, string token)
    {
        request.Headers.Add("apikey", _settings.SupabasePublishableKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private StringContent JsonContent<T>(T value) => new(
        JsonSerializer.Serialize(value, _json),
        Encoding.UTF8,
        "application/json");

    private static string ReadError(string payload, string fallback)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);
            var root = document.RootElement;
            foreach (var name in new[] { "msg", "message", "error_description", "error" })
            {
                if (root.TryGetProperty(name, out var value) &&
                    value.ValueKind == JsonValueKind.String)
                    return value.GetString() ?? fallback;
            }
        }
        catch (JsonException) { }

        return fallback;
    }

    private sealed class TokenResponse
    {
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = string.Empty;

        [JsonPropertyName("refresh_token")]
        public string RefreshToken { get; set; } = string.Empty;

        [JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; }

        [JsonPropertyName("user")]
        public TokenUser? User { get; set; }
    }

    private sealed class TokenUser
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;
    }

    private sealed class UserProfile
    {
        [JsonPropertyName("nome_cognome")]
        public string FullName { get; set; } = string.Empty;

        [JsonPropertyName("email")]
        public string Email { get; set; } = string.Empty;

        [JsonPropertyName("ruolo")]
        public string Role { get; set; } = string.Empty;

        [JsonPropertyName("attivo")]
        public bool Active { get; set; }
    }
}
