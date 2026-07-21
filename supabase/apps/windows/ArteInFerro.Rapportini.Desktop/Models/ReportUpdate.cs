namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record ReportUpdate(
    string Place,
    string? AppointmentReference,
    string InterventionType,
    DateTimeOffset StartAt,
    DateTimeOffset EndAt,
    string Description,
    string Status,
    string? AdminNote);
