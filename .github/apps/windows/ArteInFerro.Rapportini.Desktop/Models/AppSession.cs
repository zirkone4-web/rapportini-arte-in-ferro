namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record AppSession(
    string AccessToken,
    string UserId,
    string FullName,
    string Email,
    string Role);
