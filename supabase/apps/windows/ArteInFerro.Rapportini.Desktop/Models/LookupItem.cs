namespace ArteInFerro.Rapportini.Desktop.Models;

public sealed record LookupItem(string Id, string Label)
{
    public override string ToString() => Label;
}
