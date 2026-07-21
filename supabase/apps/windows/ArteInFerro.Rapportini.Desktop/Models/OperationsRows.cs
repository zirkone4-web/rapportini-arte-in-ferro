using System.Text.Json.Serialization;
namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class FuelRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("data_ora")] public DateTimeOffset DateTime { get; set; }
    [JsonPropertyName("km")] public int Km { get; set; }
    [JsonPropertyName("litri")] public decimal Liters { get; set; }
    [JsonPropertyName("importo")] public decimal? Amount { get; set; }
    [JsonPropertyName("distributore")] public string? Station { get; set; }
    [JsonPropertyName("dipendente")] public UserShort? Employee { get; set; }
    [JsonPropertyName("mezzo")] public VehicleShort? Vehicle { get; set; }
    public string EmployeeName => Employee?.Name ?? string.Empty;
    public string VehicleName => Vehicle is null ? string.Empty : $"{Vehicle.Plate} · {Vehicle.Description}";
}

public sealed class AnomalyRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("tipo")] public string Type { get; set; } = string.Empty;
    [JsonPropertyName("stato")] public string Status { get; set; } = string.Empty;
    [JsonPropertyName("titolo")] public string Title { get; set; } = string.Empty;
    [JsonPropertyName("descrizione")] public string Description { get; set; } = string.Empty;
    [JsonPropertyName("luogo")] public string? Place { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("dipendente")] public UserShort? Employee { get; set; }
    [JsonPropertyName("mezzo")] public VehicleShort? Vehicle { get; set; }
    public string EmployeeName => Employee?.Name ?? string.Empty;
    public string VehicleName => Vehicle is null ? string.Empty : $"{Vehicle.Plate} · {Vehicle.Description}";
}

public sealed class UserShort
{
    [JsonPropertyName("nome_cognome")] public string Name { get; set; } = string.Empty;
}
