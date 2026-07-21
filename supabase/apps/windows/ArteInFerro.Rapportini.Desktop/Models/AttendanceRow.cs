using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class AttendanceRow
{
    [JsonPropertyName("dipendente_id")] public string EmployeeId { get; set; } = string.Empty;
    [JsonPropertyName("nome_cognome")] public string EmployeeName { get; set; } = string.Empty;
    [JsonPropertyName("giorno")] public DateTime Day { get; set; }
    [JsonPropertyName("prima_entrata")] public DateTimeOffset? FirstEntry { get; set; }
    [JsonPropertyName("ultima_uscita")] public DateTimeOffset? LastExit { get; set; }
    [JsonPropertyName("ore_totali")] public decimal? TotalHours { get; set; }
    [JsonPropertyName("ore_straordinarie")] public decimal? OvertimeHours { get; set; }
    [JsonPropertyName("stato_ore")] public string HoursStatus { get; set; } = "da_autorizzare";
    [JsonPropertyName("ore_autorizzate")] public decimal? AuthorizedHours { get; set; }
    [JsonPropertyName("nota_amministratore")] public string? AdminNote { get; set; }
    [JsonPropertyName("contiene_trasferta_da_verificare")] public bool HasPendingTransfer { get; set; }
    [JsonPropertyName("contiene_timbratura_rifiutata")] public bool HasRejectedAttendance { get; set; }
    public string HoursStatusLabel => HoursStatus switch
    {
        "autorizzata" => "Autorizzata",
        "rifiutata" => "Rifiutata",
        _ => "Da autorizzare"
    };
}
