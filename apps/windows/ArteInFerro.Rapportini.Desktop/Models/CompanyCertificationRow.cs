using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class CompanyCertificationRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("categoria")] public string Type { get; set; } = string.Empty;
    [JsonPropertyName("titolo")] public string Title { get; set; } = string.Empty;
    [JsonPropertyName("ente_rilascio")] public string? Issuer { get; set; }
    [JsonPropertyName("numero_certificato")] public string? CertificateNumber { get; set; }
    [JsonPropertyName("data_rilascio")] public DateTime? IssueDate { get; set; }
    [JsonPropertyName("data_scadenza")] public DateTime? ExpiryDate { get; set; }
    [JsonPropertyName("documento_url")] public string? DocumentUrl { get; set; }
    [JsonPropertyName("attiva")] public bool Active { get; set; }
}
