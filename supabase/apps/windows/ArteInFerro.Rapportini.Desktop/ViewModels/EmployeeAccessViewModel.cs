using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class EmployeeAccessViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private EmployeeAccessRow? _selectedEmployee;
    [ObservableProperty] private LookupItem? _selectedRole;
    [ObservableProperty] private string _fullName = string.Empty;
    [ObservableProperty] private string _phone = string.Empty;
    [ObservableProperty] private string _job = string.Empty;
    [ObservableProperty] private string _department = string.Empty;
    [ObservableProperty] private DateTime? _hireDate;
    [ObservableProperty] private DateTime? _endDate;
    [ObservableProperty] private bool _active = true;
    [ObservableProperty] private string _reason = string.Empty;
    [ObservableProperty] private string _temporaryPassword = string.Empty;
    [ObservableProperty] private string _message = "Seleziona un dipendente o amministratore.";
    [ObservableProperty] private bool _isBusy;

    public EmployeeAccessViewModel(SupabaseApiService api)
    {
        _api = api;
        Roles.Add(new LookupItem("operatore", "Operatore"));
        Roles.Add(new LookupItem("admin", "Amministratore"));
        SelectedRole = Roles[0];
        _ = LoadAsync();
    }

    public ObservableCollection<EmployeeAccessRow> Employees { get; } = [];
    public ObservableCollection<LookupItem> Roles { get; } = [];

    partial void OnSelectedEmployeeChanged(EmployeeAccessRow? value)
    {
        if (value is null) return;
        FullName = value.FullName;
        SelectedRole = Roles.FirstOrDefault(x => x.Id == value.Role) ?? Roles[0];
        Active = value.Active;
        Phone = value.Profile?.Phone ?? string.Empty;
        Job = value.Profile?.Job ?? string.Empty;
        Department = value.Profile?.Department ?? string.Empty;
        HireDate = value.Profile?.HireDate;
        EndDate = value.Profile?.EndDate;
        Reason = string.Empty;
    }

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var rows = await _api.GetEmployeeAccessAsync();
            Employees.Clear(); foreach (var row in rows) Employees.Add(row);
            Message = $"{Employees.Count} account aziendali";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SaveEmployeeAsync()
    {
        if (SelectedEmployee is null || SelectedRole is null)
        { Message = "Seleziona un account."; return; }
        if (FullName.Trim().Length < 3)
        { Message = "Inserisci nome e cognome."; return; }
        await RunAsync(() => _api.SaveEmployeeAsync(SelectedEmployee, FullName,
            SelectedRole.Id, Active, Phone, Job, Department, HireDate, EndDate, Reason));
    }

    [RelayCommand]
    private async Task ResetPasswordAsync()
    {
        if (SelectedEmployee is null || TemporaryPassword.Length < 10)
        {
            Message = "Seleziona un account e inserisci almeno 10 caratteri.";
            return;
        }
        if (Reason.Trim().Length < 3)
        { Message = "Inserisci la motivazione della modifica."; return; }
        IsBusy = true;
        try
        {
            await _api.SetTemporaryPasswordAsync(SelectedEmployee.Id, TemporaryPassword);
            TemporaryPassword = string.Empty;
            Message = "Password temporanea aggiornata. Comunicala in modo riservato.";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    private async Task RunAsync(Func<Task> operation)
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            await operation();
            IsBusy = false;
            await LoadAsync();
            Reason = string.Empty;
            Message = "Anagrafica aggiornata e modifica registrata nello storico.";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }
}
