using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class OperationsViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private AnomalyRow? _selectedAnomaly;
    [ObservableProperty] private string _resolutionNote = string.Empty;
    [ObservableProperty] private string _message = "Rifornimenti e segnalazioni dal campo.";
    [ObservableProperty] private bool _isBusy;
    public ObservableCollection<FuelRow> FuelEntries { get; } = [];
    public ObservableCollection<AnomalyRow> Anomalies { get; } = [];

    public OperationsViewModel(SupabaseApiService api) { _api = api; _ = LoadAsync(); }

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return; IsBusy = true;
        try
        {
            var fuel = await _api.GetFuelEntriesAsync(); var anomalies = await _api.GetAnomaliesAsync();
            FuelEntries.Clear(); foreach (var row in fuel) FuelEntries.Add(row);
            Anomalies.Clear(); foreach (var row in anomalies) Anomalies.Add(row);
            Message = $"{FuelEntries.Count} rifornimenti · {Anomalies.Count} anomalie";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task ResolveAsync()
    {
        if (SelectedAnomaly is null || ResolutionNote.Trim().Length < 3)
        { Message = "Seleziona l’anomalia e inserisci la nota di risoluzione."; return; }
        IsBusy = true;
        try
        {
            await _api.ResolveAnomalyAsync(SelectedAnomaly.Id, ResolutionNote);
            ResolutionNote = string.Empty; IsBusy = false; await LoadAsync();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }
}
