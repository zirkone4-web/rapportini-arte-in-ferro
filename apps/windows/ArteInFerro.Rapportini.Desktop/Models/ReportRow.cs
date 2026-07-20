using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class ReportRow
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("dipendente_id")]
    public string EmployeeId { get; set; } = string.Empty;

    [JsonPropertyName("cliente_id")]
    public string ClientId { get; set; } = string.Empty;

    [JsonPropertyName("luogo")]
    public string Place { get; set; } = string.Empty;

    [JsonPropertyName("rif_appuntamento")]
    public string? AppointmentReference { get; set; }

    [JsonPropertyName("tipologia_intervento")]
    public string InterventionType { get; set; } = string.Empty;

    [JsonPropertyName("data_ora_inizio")]
    public DateTimeOffset StartAt { get; set; }

    [JsonPropertyName("data_ora_fine")]
    public DateTimeOffset? EndAt { get; set; }

    [JsonPropertyName("ore_totali")]
    public decimal TotalHours { get; set; }

    [JsonPropertyName("descrizione")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("firma_cliente_url")]
    public string? SignaturePath { get; set; }

    [JsonPropertyName("gps_latitudine")]
    public decimal? Latitude { get; set; }

    [JsonPropertyName("gps_longitudine")]
    public decimal? Longitude { get; set; }

    [JsonPropertyName("gps_precisione_metri")]
    public decimal? GpsAccuracy { get; set; }

    [JsonPropertyName("gps_rilevato_at")]
    public DateTimeOffset? GpsCapturedAt { get; set; }

    [JsonPropertyName("stato")]
    public string Status { get; set; } = string.Empty;

    [JsonPropertyName("nota_amministratore")]
    public string? AdminNote { get; set; }

    [JsonPropertyName("created_at")]
    public DateTimeOffset CreatedAt { get; set; }

    [JsonPropertyName("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; }

    [JsonPropertyName("versione")]
    public long Version { get; set; }

    [JsonPropertyName("dipendente")]
    public EmployeeRelation? Employee { get; set; }

    [JsonPropertyName("cliente")]
    public ClientRelation? Client { get; set; }

    [JsonIgnore]
    public string EmployeeName => Employee?.FullName ?? "—";

    [JsonIgnore]
    public string ClientName => Client?.CompanyName ?? "—";

    [JsonIgnore]
    public string InterventionLabel => InterventionType switch
    {
        "montaggio_posa" => "Montaggio / posa",
        "manutenzione_riparazione" => "Manutenzione / riparazione",
        "sopralluogo" => "Sopralluogo",
        "consegna_ritiro" => "Consegna / ritiro",
        "lavorazione_officina" => "Lavorazione in officina",
        _ => "Altro"
    };
}

public sealed class EmployeeRelation
{
    [JsonPropertyName("nome_cognome")]
    public string FullName { get; set; } = string.Empty;
}

public sealed class ClientRelation
{
    [JsonPropertyName("ragione_sociale")]
    public string CompanyName { get; set; } = string.Empty;
}
