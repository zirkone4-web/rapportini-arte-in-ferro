using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class DeadlineRow
{
    [JsonPropertyName("ambito")] public string Scope { get; set; } = string.Empty;
    [JsonPropertyName("elemento_id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("soggetto")] public string Subject { get; set; } = string.Empty;
    [JsonPropertyName("categoria")] public string Category { get; set; } = string.Empty;
    [JsonPropertyName("titolo")] public string Title { get; set; } = string.Empty;
    [JsonPropertyName("data_scadenza")] public DateTime ExpiryDate { get; set; }
    [JsonPropertyName("documento_url")] public string? DocumentUrl { get; set; }
    [JsonPropertyName("giorni_rimanenti")] public int RemainingDays { get; set; }
    public string Status => RemainingDays < 0 ? "SCADUTA" : RemainingDays <= 30 ? "IN SCADENZA" : "REGOLARE";
}
