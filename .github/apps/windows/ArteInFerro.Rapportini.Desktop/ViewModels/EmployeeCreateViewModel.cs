using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class EmployeeCreateViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;

    [ObservableProperty] private string _fullName = string.Empty;
    [ObservableProperty] private string _email = string.Empty;
    [ObservableProperty] private string _temporaryPassword = string.Empty;
    [ObservableProperty] private string _phone = string.Empty;
    [ObservableProperty] private string _job = string.Empty;
    [ObservableProperty] private string _department = string.Empty;
    [ObservableProperty] private DateTime? _hireDate = DateTime.Today;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _message = "La password è temporanea e deve avere almeno 10 caratteri.";

    public EmployeeCreateViewModel(SupabaseApiService api) => _api = api;

    public event Action? Saved;

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (IsBusy) return;
        if (FullName.Trim().Length < 3 || !Email.Contains('@') || TemporaryPassword.Length < 10)
        {
            Message = "Controlla nome, email e password temporanea.";
            return;
        }

        IsBusy = true;
        Message = "Creazione accesso Supabase…";
        try
        {
            await _api.CreateEmployeeAsync(new EmployeeCreateRequest(
                FullName, Email, TemporaryPassword, Phone, Job, Department, HireDate));
            Message = "Dipendente e accesso creati correttamente.";
            Saved?.Invoke();
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            Message = ex is TaskCanceledException ? "Operazione scaduta." : ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }
}
