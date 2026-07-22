using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class CompanySettingsRow
{
    [JsonPropertyName("ragione_sociale")] public string CompanyName { get; set; } = string.Empty;
    [JsonPropertyName("partita_iva")] public string? VatNumber { get; set; }
    [JsonPropertyName("codice_fiscale")] public string? FiscalCode { get; set; }
    [JsonPropertyName("indirizzo")] public string? Address { get; set; }
    [JsonPropertyName("comune")] public string? City { get; set; }
    [JsonPropertyName("provincia")] public string? Province { get; set; }
    [JsonPropertyName("cap")] public string? PostalCode { get; set; }
    [JsonPropertyName("email")] public string? Email { get; set; }
    [JsonPropertyName("pec")] public string? Pec { get; set; }
    [JsonPropertyName("telefono_principale")] public string? Phone { get; set; }
    [JsonPropertyName("sito_web")] public string? Website { get; set; }
    [JsonPropertyName("gps_latitudine")] public decimal? Latitude { get; set; }
    [JsonPropertyName("gps_longitudine")] public decimal? Longitude { get; set; }
    [JsonPropertyName("raggio_presenza_metri")] public int AttendanceRadiusMeters { get; set; } = 200;
    [JsonPropertyName("controllo_gps_presenze")] public bool AttendanceGpsEnabled { get; set; }
    [JsonPropertyName("motivo_modifica")] public string? ModificationReason { get; set; }
}

public sealed class CompanyContactRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("nome")] public string Name { get; set; } = string.Empty;
    [JsonPropertyName("ruolo_reparto")] public string DepartmentRole { get; set; } = string.Empty;
    [JsonPropertyName("telefono")] public string? Phone { get; set; }
    [JsonPropertyName("email")] public string? Email { get; set; }
    [JsonPropertyName("tipo")] public string Type { get; set; } = string.Empty;
    [JsonPropertyName("visibile_operatori")] public bool VisibleToEmployees { get; set; }
}
