using System.Text.Json.Serialization;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class EmployeeAccessRow
{
    [JsonPropertyName("id")] public string Id { get; set; } = string.Empty;
    [JsonPropertyName("nome_cognome")] public string FullName { get; set; } = string.Empty;
    [JsonPropertyName("email")] public string Email { get; set; } = string.Empty;
    [JsonPropertyName("ruolo")] public string Role { get; set; } = string.Empty;
    [JsonPropertyName("attivo")] public bool Active { get; set; }
    [JsonPropertyName("dipendente_profili")] public EmployeeProfileRow? Profile { get; set; }
    public string StateLabel => Active ? "Attivo" : "Disabilitato";
}
