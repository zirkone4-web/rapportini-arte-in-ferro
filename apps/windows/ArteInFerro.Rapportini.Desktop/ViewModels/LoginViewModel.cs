using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class LoginViewModel : ObservableObject
{
    private readonly SupabaseAuthService _auth;

    [ObservableProperty]
    private string _email = string.Empty;

    [ObservableProperty]
    private string _password = string.Empty;

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string? _errorMessage;

    public LoginViewModel(SupabaseAuthService auth) => _auth = auth;

    public event Action<AppSession>? LoginSucceeded;

    [RelayCommand]
    private async Task LoginAsync()
    {
        if (IsBusy) return;
        ErrorMessage = null;
        if (string.IsNullOrWhiteSpace(Email) || string.IsNullOrEmpty(Password))
        {
            ErrorMessage = "Inserisci email e password.";
            return;
        }

        IsBusy = true;
        try
        {
            var session = await _auth.SignInAdminAsync(Email, Password);
            Password = string.Empty;
            LoginSucceeded?.Invoke(session);
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            ErrorMessage = ex is TaskCanceledException
                ? "Il server non ha risposto in tempo. Riprova."
                : ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }
}
