using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class VehicleRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("targa")] public string Plate { get; set; } = string.Empty;
    [JsonPropertyName("descrizione")] public string Description { get; set; } = string.Empty;
    [JsonPropertyName("marca")] public string? Brand { get; set; }
    [JsonPropertyName("modello")] public string? Model { get; set; }
    [JsonPropertyName("km_attuali")] public int? CurrentKm { get; set; }
    [JsonPropertyName("attivo")] public bool Active { get; set; }
    public string DisplayName => $"{Plate} · {Description}";
}

public sealed class VehicleDeadlineRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("mezzo_id")] public string VehicleId { get; set; } = string.Empty;
    [JsonPropertyName("tipo")] public string Type { get; set; } = string.Empty;
    [JsonPropertyName("descrizione")] public string Description { get; set; } = string.Empty;
    [JsonPropertyName("fornitore_ente")] public string? Provider { get; set; }
    [JsonPropertyName("numero_documento")] public string? DocumentNumber { get; set; }
    [JsonPropertyName("data_scadenza")] public DateTime ExpiryDate { get; set; }
    [JsonPropertyName("completata")] public bool Completed { get; set; }
    [JsonPropertyName("mezzo")] public VehicleShort? Vehicle { get; set; }
    public string VehicleName => Vehicle is null ? string.Empty : $"{Vehicle.Plate} · {Vehicle.Description}";
}

public sealed class VehicleShort
{
    [JsonPropertyName("targa")] public string Plate { get; set; } = string.Empty;
    [JsonPropertyName("descrizione")] public string Description { get; set; } = string.Empty;
}
