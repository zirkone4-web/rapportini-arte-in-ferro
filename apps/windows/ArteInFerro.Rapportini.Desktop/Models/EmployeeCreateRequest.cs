namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record EmployeeCreateRequest(
    string FullName,
    string Email,
    string TemporaryPassword,
    string? Phone,
    string? Job,
    string? Department,
    DateTime? HireDate);
