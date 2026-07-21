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
    [ObservableProperty] private string _temporaryPassword = string.Empty;
    [ObservableProperty] private string _message = "Seleziona un dipendente per gestire il suo accesso.";
    [ObservableProperty] private bool _isBusy;

    public EmployeeAccessViewModel(SupabaseApiService api)
    {
        _api = api;
        _ = LoadAsync();
    }

    public ObservableCollection<EmployeeAccessRow> Employees { get; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var rows = await _api.GetEmployeeAccessAsync();
            Employees.Clear();
            foreach (var row in rows.Where(x => x.Role == "operatore")) Employees.Add(row);
            Message = $"{Employees.Count} dipendenti";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task ToggleActiveAsync()
    {
        if (SelectedEmployee is null) { Message = "Seleziona un dipendente."; return; }
        IsBusy = true;
        try
        {
            await _api.SetEmployeeActiveAsync(SelectedEmployee.Id, !SelectedEmployee.Active);
            Message = !SelectedEmployee.Active ? "Accesso riattivato." : "Accesso disabilitato.";
            IsBusy = false;
            await LoadAsync();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task ResetPasswordAsync()
    {
        if (SelectedEmployee is null || TemporaryPassword.Length < 10)
        {
            Message = "Seleziona un dipendente e inserisci almeno 10 caratteri.";
            return;
        }
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
}
