using System.Text.Json;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class AppSettings
{
    public string SupabaseUrl { get; init; } = string.Empty;
    public string SupabasePublishableKey { get; init; } = string.Empty;

    public static AppSettings Load()
    {
        var filePath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
        var fromFile = File.Exists(filePath)
            ? JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(filePath))
            : null;
        var settings = new AppSettings
        {
            SupabaseUrl = Environment.GetEnvironmentVariable("SUPABASE_URL")
                ?? fromFile?.SupabaseUrl
                ?? string.Empty,
            SupabasePublishableKey =
                Environment.GetEnvironmentVariable("SUPABASE_PUBLISHABLE_KEY")
                ?? fromFile?.SupabasePublishableKey
                ?? string.Empty
        };

        if (!Uri.TryCreate(settings.SupabaseUrl, UriKind.Absolute, out _) ||
            settings.SupabaseUrl.Contains("INSERISCI", StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(settings.SupabasePublishableKey) ||
            settings.SupabasePublishableKey.Contains("INSERISCI", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Configura SupabaseUrl e SupabasePublishableKey in appsettings.json " +
                "oppure nelle variabili SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY.");
        }

        return settings;
    }
}
