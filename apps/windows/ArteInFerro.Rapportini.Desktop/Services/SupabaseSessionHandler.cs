using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using ArteInFerro.Rapportini.Desktop.Models;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class SupabaseSessionHandler : DelegatingHandler
{
    private readonly AppSettings _settings;
    private readonly AppSession _session;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web);

    public SupabaseSessionHandler(AppSettings settings, AppSession session)
        : base(new HttpClientHandler())
    {
        _settings = settings;
        _session = session;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        if (_session.ShouldRefresh)
            await RefreshSessionAsync(null, cancellationToken);

        request.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", _session.AccessToken);

        using var retryRequest = await CloneRequestAsync(request, cancellationToken);
        var tokenUsed = _session.AccessToken;
        var response = await base.SendAsync(request, cancellationToken);

        if (response.StatusCode != HttpStatusCode.Unauthorized)
            return response;

        response.Dispose();
        await RefreshSessionAsync(tokenUsed, cancellationToken);
        retryRequest.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", _session.AccessToken);

        return await base.SendAsync(retryRequest, cancellationToken);
    }

    private async Task RefreshSessionAsync(
        string? failedAccessToken,
        CancellationToken cancellationToken)
    {
        await _refreshLock.WaitAsync(cancellationToken);
        try
        {
            if (failedAccessToken is null)
            {
                if (!_session.ShouldRefresh) return;
            }
            else if (!string.Equals(
                         _session.AccessToken,
                         failedAccessToken,
                         StringComparison.Ordinal))
            {
                return;
            }

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                $"{_settings.SupabaseUrl.TrimEnd('/')}/auth/v1/token" +
                "?grant_type=refresh_token");
            request.Headers.Add("apikey", _settings.SupabasePublishableKey);
            request.Content = new StringContent(
                JsonSerializer.Serialize(
                    new { refresh_token = _session.RefreshToken },
                    _json),
                Encoding.UTF8,
                "application/json");

            using var response = await base.SendAsync(request, cancellationToken);
            var payload = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
                throw new ApiException(
                    "La sessione è scaduta. Chiudi il programma e accedi nuovamente.");

            var token = JsonSerializer.Deserialize<RefreshResponse>(payload, _json)
                ?? throw new ApiException("Rinnovo della sessione non valido.");
            if (string.IsNullOrWhiteSpace(token.AccessToken))
                throw new ApiException("Supabase non ha restituito un nuovo access token.");

            _session.UpdateTokens(
                token.AccessToken,
                token.RefreshToken,
                token.ExpiresIn);
        }
        finally
        {
            _refreshLock.Release();
        }
    }

    private static async Task<HttpRequestMessage> CloneRequestAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var clone = new HttpRequestMessage(request.Method, request.RequestUri)
        {
            Version = request.Version,
            VersionPolicy = request.VersionPolicy
        };

        foreach (var header in request.Headers)
            clone.Headers.TryAddWithoutValidation(header.Key, header.Value);

        foreach (var option in request.Options)
            clone.Options.TryAdd(option.Key, option.Value);

        if (request.Content is not null)
        {
            var bytes = await request.Content.ReadAsByteArrayAsync(cancellationToken);
            clone.Content = new ByteArrayContent(bytes);
            foreach (var header in request.Content.Headers)
                clone.Content.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        return clone;
    }

    private sealed class RefreshResponse
    {
        [JsonPropertyName("access_token")]
        public string AccessToken { get; set; } = string.Empty;

        [JsonPropertyName("refresh_token")]
        public string RefreshToken { get; set; } = string.Empty;

        [JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; }
    }
}
