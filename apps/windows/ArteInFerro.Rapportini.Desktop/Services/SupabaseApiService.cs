using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using ArteInFerro.Rapportini.Desktop.Models;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class SupabaseApiService
{
    private readonly HttpClient _http;
    private readonly AppSettings _settings;
    private readonly AppSession _session;
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web);

    public SupabaseApiService(HttpClient http, AppSettings settings, AppSession session)
    {
        _http = http;
        _settings = settings;
        _session = session;
    }

    public AppSession Session => _session;

    public async Task<IReadOnlyList<ReportRow>> GetReportsAsync(
        CancellationToken cancellationToken = default)
    {
        const string select = "id,dipendente_id,cliente_id,luogo,rif_appuntamento," +
            "tipologia_intervento,data_ora_inizio,data_ora_fine,ore_totali,descrizione," +
            "firma_cliente_url,gps_latitudine,gps_longitudine,gps_precisione_metri," +
            "gps_rilevato_at,stato,nota_amministratore,created_at,updated_at,versione," +
            "dipendente:utenti!rapportini_dipendente_id_fkey(nome_cognome)," +
            "cliente:clienti!rapportini_cliente_id_fkey(ragione_sociale)";
        var uri = RestUri("rapportini") +
                  $"?select={Uri.EscapeDataString(select)}&order=data_ora_inizio.desc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
    }

    public async Task<IReadOnlyList<LookupItem>> GetEmployeesAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("utenti") + "?select=id,nome_cognome&attivo=eq.true&order=nome_cognome",
            null,
            cancellationToken);
        var rows = JsonSerializer.Deserialize<List<UserLookup>>(payload, _json) ?? [];
        return rows.Select(row => new LookupItem(row.Id, row.Name)).ToList();
    }

    public async Task<IReadOnlyList<LookupItem>> GetClientsAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("clienti") + "?select=id,ragione_sociale&order=ragione_sociale",
            null,
            cancellationToken);
        var rows = JsonSerializer.Deserialize<List<ClientLookup>>(payload, _json) ?? [];
        return rows.Select(row => new LookupItem(row.Id, row.Name)).ToList();
    }

    public async Task<ReportRow> UpdateReportAsync(
        ReportRow original,
        ReportUpdate update,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["luogo"] = update.Place.Trim(),
            ["rif_appuntamento"] = EmptyToNull(update.AppointmentReference),
            ["tipologia_intervento"] = update.InterventionType,
            ["data_ora_inizio"] = update.StartAt.ToUniversalTime().ToString("O"),
            ["data_ora_fine"] = update.EndAt.ToUniversalTime().ToString("O"),
            ["descrizione"] = update.Description.Trim(),
            ["stato"] = update.Status,
            ["nota_amministratore"] = EmptyToNull(update.AdminNote)
        };
        var uri = RestUri("rapportini") +
                  $"?id=eq.{Uri.EscapeDataString(original.Id)}" +
                  $"&versione=eq.{original.Version}&select=*";
        var payload = await SendAsync(HttpMethod.Patch, uri, body, cancellationToken, true);
        var rows = JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
        return rows.SingleOrDefault() ?? throw new ConcurrencyException();
    }

    public async Task<ReportRow> SetStatusAsync(
        ReportRow original,
        string status,
        string? note,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["stato"] = status,
            ["nota_amministratore"] = EmptyToNull(note)
        };
        var uri = RestUri("rapportini") +
                  $"?id=eq.{Uri.EscapeDataString(original.Id)}" +
                  $"&versione=eq.{original.Version}&select=*";
        var payload = await SendAsync(HttpMethod.Patch, uri, body, cancellationToken, true);
        var rows = JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
        return rows.SingleOrDefault() ?? throw new ConcurrencyException();
    }

    public async Task<ReportMedia> GetMediaAsync(
        ReportRow report,
        CancellationToken cancellationToken = default)
    {
        byte[]? signature = null;
        if (!string.IsNullOrWhiteSpace(report.SignaturePath))
            signature = await DownloadPrivateFileAsync(
                "rapportini-firme",
                report.SignaturePath,
                cancellationToken);

        var uri = RestUri("rapportino_foto") +
                  $"?rapportino_id=eq.{Uri.EscapeDataString(report.Id)}" +
                  "&select=foto_url&order=created_at";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        var paths = JsonSerializer.Deserialize<List<PhotoPath>>(payload, _json) ?? [];
        var photos = new List<byte[]>();
        foreach (var item in paths.Take(6))
        {
            try
            {
                photos.Add(await DownloadPrivateFileAsync(
                    "rapportini-foto",
                    item.Path,
                    cancellationToken));
            }
            catch (ApiException)
            {
                // Un singolo allegato mancante non impedisce il PDF.
            }
        }
        return new ReportMedia(signature, photos);
    }

    private async Task<byte[]> DownloadPrivateFileAsync(
        string bucket,
        string path,
        CancellationToken cancellationToken)
    {
        var signUri = $"{_settings.SupabaseUrl.TrimEnd('/')}/storage/v1/object/sign/" +
                      $"{bucket}/{EscapePath(path)}";
        var payload = await SendAsync(
            HttpMethod.Post,
            signUri,
            new { expiresIn = 300 },
            cancellationToken);
        var signed = JsonSerializer.Deserialize<SignedUrlResponse>(payload, _json);
        if (string.IsNullOrWhiteSpace(signed?.SignedUrl))
            throw new ApiException("URL temporaneo dell’allegato non disponibile.");
        var url = signed.SignedUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase)
            ? signed.SignedUrl
            : $"{_settings.SupabaseUrl.TrimEnd('/')}/storage/v1" +
              (signed.SignedUrl.StartsWith('/') ? signed.SignedUrl : "/" + signed.SignedUrl);
        using var response = await _http.GetAsync(url, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException("Impossibile scaricare un allegato privato.");
        return await response.Content.ReadAsByteArrayAsync(cancellationToken);
    }

    private async Task<string> SendAsync(
        HttpMethod method,
        string uri,
        object? body,
        CancellationToken cancellationToken,
        bool returnRepresentation = false)
    {
        using var request = new HttpRequestMessage(method, uri);
        request.Headers.Add("apikey", _settings.SupabasePublishableKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _session.AccessToken);
        if (returnRepresentation)
            request.Headers.TryAddWithoutValidation("Prefer", "return=representation");
        if (body is not null)
        {
            request.Content = new StringContent(
                JsonSerializer.Serialize(body, _json),
                Encoding.UTF8,
                "application/json");
        }

        using var response = await _http.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException(ReadError(payload));
        return payload;
    }

    private string RestUri(string table) =>
        $"{_settings.SupabaseUrl.TrimEnd('/')}/rest/v1/{table}";

    private static string EscapePath(string path) => string.Join(
        '/',
        path.Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Select(Uri.EscapeDataString));

    private static string? EmptyToNull(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string ReadError(string payload)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);
            var root = document.RootElement;
            foreach (var name in new[] { "message", "msg", "hint", "details" })
            {
                if (root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String)
                    return value.GetString() ?? "Errore di comunicazione con Supabase.";
            }
        }
        catch (JsonException) { }
        return "Errore di comunicazione con Supabase.";
    }

    private sealed class UserLookup
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("nome_cognome")]
        public string Name { get; set; } = string.Empty;
    }

    private sealed class ClientLookup
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("ragione_sociale")]
        public string Name { get; set; } = string.Empty;
    }

    private sealed class PhotoPath
    {
        [JsonPropertyName("foto_url")]
        public string Path { get; set; } = string.Empty;
    }

    private sealed class SignedUrlResponse
    {
        [JsonPropertyName("signedURL")]
        public string SignedUrl { get; set; } = string.Empty;
    }
}
