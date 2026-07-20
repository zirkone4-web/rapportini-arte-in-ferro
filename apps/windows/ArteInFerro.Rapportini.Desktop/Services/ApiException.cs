namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class ApiException : Exception
{
    public ApiException(string message) : base(message) { }
}

public sealed class ConcurrencyException : Exception
{
    public ConcurrencyException()
        : base("Il rapportino è stato modificato da un altro utente. Aggiorna e riprova.") { }
}
