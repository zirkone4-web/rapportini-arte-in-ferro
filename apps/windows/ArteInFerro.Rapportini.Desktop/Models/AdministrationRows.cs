using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class AttendanceEventRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("dipendente_id")] public string EmployeeId { get; set; } = string.Empty;
    [JsonPropertyName("nome_cognome")] public string EmployeeName { get; set; } = string.Empty;
    [JsonPropertyName("tipo")] public string Type { get; set; } = string.Empty;
    [JsonPropertyName("registrata_at")] public DateTimeOffset RegisteredAt { get; set; }
    [JsonPropertyName("gps_latitudine")] public decimal? Latitude { get; set; }
    [JsonPropertyName("gps_longitudine")] public decimal? Longitude { get; set; }
    [JsonPropertyName("gps_precisione_metri")] public decimal? AccuracyMeters { get; set; }
    [JsonPropertyName("luogo")] public string? Place { get; set; }
    [JsonPropertyName("nota")] public string? Note { get; set; }
    [JsonPropertyName("modalita")] public string Mode { get; set; } = string.Empty;
    [JsonPropertyName("trasferta_motivo")] public string? TransferReason { get; set; }
    [JsonPropertyName("stato_verifica")] public string VerificationStatus { get; set; } = string.Empty;
    [JsonPropertyName("distanza_riferimento_metri")] public decimal? DistanceMeters { get; set; }
    [JsonPropertyName("forzata_da_amministratore")] public bool ForcedByAdmin { get; set; }
    [JsonPropertyName("cantiere_nome")] public string? WorksiteName { get; set; }
    [JsonPropertyName("cliente_nome")] public string? ClientName { get; set; }
    [JsonPropertyName("motivo_modifica")] public string? ModificationReason { get; set; }
    public string TypeLabel => Type == "entrata" ? "Entrata" : "Uscita";
    public string ModeLabel => Mode switch { "cantiere" => "Cantiere", "trasferta" => "Trasferta", _ => "Sede" };
    public string VerificationLabel => VerificationStatus switch
    {
        "valida" => "Valida",
        "rifiutata" => "Rifiutata",
        _ => "Da verificare"
    };
    public string LocationLabel => WorksiteName ?? Place ?? (ForcedByAdmin ? "Registrazione forzata" : "—");
}

public sealed class ClientRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("ragione_sociale")] public string Name { get; set; } = string.Empty;
    [JsonPropertyName("indirizzo")] public string Address { get; set; } = string.Empty;
    [JsonPropertyName("referente")] public string? Contact { get; set; }
    [JsonPropertyName("telefono")] public string? Phone { get; set; }
    [JsonPropertyName("attivo")] public bool Active { get; set; }
    public string StateLabel => Active ? "Attivo" : "Disattivato";
}

public sealed class WorksiteRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("cliente_id")] public string ClientId { get; set; } = string.Empty;
    [JsonPropertyName("nome")] public string Name { get; set; } = string.Empty;
    [JsonPropertyName("indirizzo")] public string Address { get; set; } = string.Empty;
    [JsonPropertyName("gps_latitudine")] public decimal Latitude { get; set; }
    [JsonPropertyName("gps_longitudine")] public decimal Longitude { get; set; }
    [JsonPropertyName("raggio_presenza_metri")] public int RadiusMeters { get; set; } = 200;
    [JsonPropertyName("attivo")] public bool Active { get; set; }
    [JsonPropertyName("note")] public string? Notes { get; set; }
    [JsonPropertyName("cliente")] public ClientNameRef? Client { get; set; }
    public string ClientName => Client?.Name ?? "Cliente";
    public string StateLabel => Active ? "Attivo" : "Disattivato";
}

public sealed class ClientNameRef
{
    [JsonPropertyName("ragione_sociale")] public string Name { get; set; } = string.Empty;
}

public sealed class EmployeeProfileRow
{
    [JsonPropertyName("telefono")] public string? Phone { get; set; }
    [JsonPropertyName("mansione")] public string? Job { get; set; }
    [JsonPropertyName("reparto")] public string? Department { get; set; }
    [JsonPropertyName("data_assunzione")] public DateTime? HireDate { get; set; }
    [JsonPropertyName("data_cessazione")] public DateTime? EndDate { get; set; }
}
