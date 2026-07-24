using System.Net.Http.Headers;
using System.Text.Json;
using ArteInFerro.Rapportini.Desktop.Models;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class SupabaseArchiveReader
{
    private const int MaximumRowsPerSection = 5000;

    private static readonly (string Name, string Resource)[] Definitions =
    [
        ("Dipendenti e accessi", "utenti"),
        ("Profili dipendenti", "dipendente_profili"),
        ("Clienti", "clienti"),
        ("Cantieri", "cantieri"),
        ("Rapportini", "rapportini"),
        ("Collaboratori rapportini", "rapportino_collaboratori"),
        ("Presenze giornaliere", "v_presenze_giornaliere"),
        ("Timbrature", "timbrature"),
        ("Revisioni presenze", "presenze_revisioni"),
        ("Documenti dipendenti", "dipendente_documenti"),
        ("Mezzi", "mezzi"),
        ("Scadenze mezzi", "scadenze_mezzi"),
        ("Rifornimenti", "rifornimenti"),
        ("Anomalie", "anomalie"),
        ("Comunicazioni", "comunicazioni"),
        ("Destinatari comunicazioni", "comunicazione_destinatari"),
        ("Richieste materiali", "richieste_materiale"),
        ("Righe richieste materiali", "richiesta_materiale_righe"),
        ("Certificazioni azienda", "certificazioni_azienda"),
        ("Contatti azienda", "contatti_azienda"),
        ("Dati azienda", "configurazione_azienda"),
        ("Scadenziario", "v_scadenziario")
    ];

    private readonly HttpClient _http;
    private readonly AppSettings _settings;
    private readonly AppSession _session;

    public SupabaseArchiveReader(
        HttpClient http,
        AppSettings settings,
        AppSession session)
    {
        _http = http;
        _settings = settings;
        _session = session;
    }

    public async Task<IReadOnlyList<ArchiveSection>> LoadAsync(
        CancellationToken cancellationToken = default)
    {
        var sections = new List<ArchiveSection>(Definitions.Length);

        // Lettura volutamente sequenziale: niente raffiche di richieste verso Supabase.
        foreach (var definition in Definitions)
        {
            cancellationToken.ThrowIfCancellationRequested();
            sections.Add(await LoadSectionAsync(
                definition.Name,
                definition.Resource,
                cancellationToken));
        }

        return sections;
    }

    private async Task<ArchiveSection> LoadSectionAsync(
        string name,
        string resource,
        CancellationToken cancellationToken)
    {
        try
        {
            var uri = $"{_settings.SupabaseUrl.TrimEnd('/')}/rest/v1/{resource}" +
                      $"?select=*&limit={MaximumRowsPerSection}";
            using var request = new HttpRequestMessage(HttpMethod.Get, uri);
            request.Headers.Add("apikey", _settings.SupabasePublishableKey);
            request.Headers.Authorization =
                new AuthenticationHeaderValue("Bearer", _session.AccessToken);
            request.Headers.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));

            using var response = await _http.SendAsync(request, cancellationToken);
            var payload = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
                return ArchiveSection.Error(
                    name,
                    $"Sezione non disponibile: {ReadError(payload)}");

            return ArchiveSection.FromJson(name, payload);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return ArchiveSection.Error(name, "Tempo di lettura scaduto.");
        }
        catch (Exception exception) when (
            exception is HttpRequestException or JsonException or ApiException)
        {
            return ArchiveSection.Error(name, exception.Message);
        }
    }

    private static string ReadError(string payload)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);
            foreach (var key in new[]
                     {
                         "message", "error", "msg", "hint", "details",
                         "error_description"
                     })
            {
                if (document.RootElement.TryGetProperty(key, out var value) &&
                    value.ValueKind == JsonValueKind.String)
                {
                    return value.GetString() ?? "Errore Supabase.";
                }
            }
        }
        catch (JsonException)
        {
        }

        return "Errore Supabase.";
    }
}
