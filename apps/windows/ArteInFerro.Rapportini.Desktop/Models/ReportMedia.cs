namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record ReportMedia(byte[]? Signature, IReadOnlyList<byte[]> Photos);
