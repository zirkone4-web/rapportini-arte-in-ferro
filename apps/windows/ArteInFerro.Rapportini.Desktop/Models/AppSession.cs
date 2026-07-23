namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed class AppSession
{
    public AppSession(
        string accessToken,
        string refreshToken,
        DateTimeOffset expiresAt,
        string userId,
        string fullName,
        string email,
        string role)
    {
        AccessToken = accessToken;
        RefreshToken = refreshToken;
        ExpiresAt = expiresAt;
        UserId = userId;
        FullName = fullName;
        Email = email;
        Role = role;
    }

    public string AccessToken { get; private set; }
    public string RefreshToken { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }
    public string UserId { get; }
    public string FullName { get; }
    public string Email { get; }
    public string Role { get; }

    public bool ShouldRefresh =>
        DateTimeOffset.UtcNow >= ExpiresAt.Subtract(TimeSpan.FromMinutes(2));

    public void UpdateTokens(string accessToken, string refreshToken, int expiresInSeconds)
    {
        AccessToken = accessToken;
        if (!string.IsNullOrWhiteSpace(refreshToken))
            RefreshToken = refreshToken;

        var lifetime = expiresInSeconds > 0 ? expiresInSeconds : 3600;
        ExpiresAt = DateTimeOffset.UtcNow.AddSeconds(lifetime);
    }
}
