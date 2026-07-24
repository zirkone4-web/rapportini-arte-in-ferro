using System.Text.Json;

namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record ArchiveSection(
    string Name,
    IReadOnlyList<string> Columns,
    IReadOnlyList<IReadOnlyDictionary<string, string>> Rows)
{
    public static ArchiveSection FromJson(string name, string payload)
    {
        using var document = JsonDocument.Parse(payload);
        var columns = new List<string>();
        var knownColumns = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var rows = new List<IReadOnlyDictionary<string, string>>();

        if (document.RootElement.ValueKind != JsonValueKind.Array)
            return Error(name, "Risposta dati non valida.");

        foreach (var element in document.RootElement.EnumerateArray())
        {
            var row = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (element.ValueKind == JsonValueKind.Object)
            {
                foreach (var property in element.EnumerateObject())
                    Flatten(property.Value, property.Name, row);
            }
            else
            {
                row["Valore"] = FormatValue(element);
            }

            foreach (var key in row.Keys)
            {
                if (knownColumns.Add(key)) columns.Add(key);
            }
            rows.Add(row);
        }

        return new ArchiveSection(name, columns, rows);
    }

    public static ArchiveSection Error(string name, string message) => new(
        name,
        ["Esito"],
        [new Dictionary<string, string> { ["Esito"] = message }]);

    private static void Flatten(
        JsonElement element,
        string prefix,
        IDictionary<string, string> destination)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
                Flatten(property.Value, $"{prefix}.{property.Name}", destination);
            return;
        }

        if (element.ValueKind == JsonValueKind.Array)
        {
            destination[prefix] = element.GetRawText();
            return;
        }

        destination[prefix] = FormatValue(element);
    }

    private static string FormatValue(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.String => element.GetString() ?? string.Empty,
        JsonValueKind.True => "Sì",
        JsonValueKind.False => "No",
        JsonValueKind.Null or JsonValueKind.Undefined => string.Empty,
        _ => element.GetRawText()
    };
}
