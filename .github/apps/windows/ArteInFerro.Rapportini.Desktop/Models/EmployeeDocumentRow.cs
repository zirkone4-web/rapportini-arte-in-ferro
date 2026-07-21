using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class EmployeeDocumentRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("dipendente_id")] public string EmployeeId { get; set; } = string.Empty;
    [JsonPropertyName("categoria")] public string Category { get; set; } = string.Empty;
    [JsonPropertyName("titolo")] public string Title { get; set; } = string.Empty;
    [JsonPropertyName("ente_rilascio")] public string? Issuer { get; set; }
    [JsonPropertyName("numero_documento")] public string? DocumentNumber { get; set; }
    [JsonPropertyName("data_rilascio")] public DateTime? IssueDate { get; set; }
    [JsonPropertyName("data_scadenza")] public DateTime? ExpiryDate { get; set; }
    [JsonPropertyName("esito_idoneita")] public string? Fitness { get; set; }
    [JsonPropertyName("documento_url")] public string? DocumentUrl { get; set; }
    [JsonPropertyName("visibile_dipendente")] public bool VisibleToEmployee { get; set; }
    [JsonPropertyName("dipendente")] public EmployeeName? Employee { get; set; }
    public string EmployeeName => Employee?.Name ?? string.Empty;
}

public sealed class EmployeeName
{
    [JsonPropertyName("nome_cognome")] public string Name { get; set; } = string.Empty;
}
