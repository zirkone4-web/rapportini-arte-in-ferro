using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class AdministrativeReportRequest
{
    public required string EmployeeId { get; init; }
    public required string ClientId { get; init; }
    public string? VehicleId { get; init; }
    public string? VehiclePlate { get; init; }
    public required string Place { get; init; }
    public string? AppointmentReference { get; init; }
    public required string InterventionType { get; init; }
    public required DateTimeOffset StartAt { get; init; }
    public required DateTimeOffset EndAt { get; init; }
    public required string Description { get; init; }
    public string? PlanningNotes { get; init; }
    public bool IsPlanned { get; init; }
    public IReadOnlyCollection<string> CollaboratorIds { get; init; } = [];
}

public sealed class PlanningWorksiteItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("cliente_id")]
    public string ClientId { get; set; } = string.Empty;

    [JsonPropertyName("nome")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("indirizzo")]
    public string Address { get; set; } = string.Empty;

    public override string ToString() => string.IsNullOrWhiteSpace(Address)
        ? Name
        : $"{Name} · {Address}";
}