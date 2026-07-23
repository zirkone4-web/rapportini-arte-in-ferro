namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class AttendanceGridRow
{
    public string EmployeeId { get; init; } = string.Empty;
    public string EmployeeName { get; init; } = string.Empty;
    public string AccessLabel { get; init; } = "Accesso attivo";
    public string StatusLabel { get; init; } = "Senza timbrature";
    public DateTimeOffset? FirstEntry { get; init; }
    public DateTimeOffset? LastExit { get; init; }
    public int WorkedDays { get; init; }
    public int MissingDays { get; init; }
    public decimal TotalHours { get; init; }
    public decimal CompensationHours { get; init; }
    public int PendingTransfers { get; init; }
    public DateTime? ReferenceDay { get; init; }
}
