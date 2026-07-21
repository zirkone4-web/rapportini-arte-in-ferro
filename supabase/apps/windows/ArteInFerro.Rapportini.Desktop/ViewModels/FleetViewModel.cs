using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class FleetViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private string _plate = string.Empty;
    [ObservableProperty] private string _description = string.Empty;
    [ObservableProperty] private string _brand = string.Empty;
    [ObservableProperty] private string _model = string.Empty;
    [ObservableProperty] private string _currentKm = string.Empty;
    [ObservableProperty] private VehicleRow? _selectedVehicle;
    [ObservableProperty] private LookupItem? _selectedDeadlineType;
    [ObservableProperty] private string _deadlineDescription = string.Empty;
    [ObservableProperty] private string _provider = string.Empty;
    [ObservableProperty] private string _documentNumber = string.Empty;
    [ObservableProperty] private DateTime? _expiryDate;
    [ObservableProperty] private string _message = "Gestione mezzi e relative scadenze.";
    [ObservableProperty] private bool _isBusy;

    public FleetViewModel(SupabaseApiService api)
    {
        _api = api;
        foreach (var item in new[]
        {
            new LookupItem("assicurazione", "Assicurazione"),
            new LookupItem("revisione", "Revisione"),
            new LookupItem("bollo", "Bollo"),
            new LookupItem("tagliando", "Tagliando"),
            new LookupItem("manutenzione", "Manutenzione"),
            new LookupItem("verifica_gru", "Verifica gru"),
            new LookupItem("tachigrafo", "Tachigrafo"),
            new LookupItem("altro", "Altro")
        }) DeadlineTypes.Add(item);
        SelectedDeadlineType = DeadlineTypes[0];
        _ = LoadAsync();
    }

    public ObservableCollection<VehicleRow> Vehicles { get; } = [];
    public ObservableCollection<VehicleDeadlineRow> Deadlines { get; } = [];
    public ObservableCollection<LookupItem> DeadlineTypes { get; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var vehicles = await _api.GetVehiclesAsync();
            var deadlines = await _api.GetVehicleDeadlinesAsync();
            Vehicles.Clear();
            foreach (var item in vehicles) Vehicles.Add(item);
            Deadlines.Clear();
            foreach (var item in deadlines) Deadlines.Add(item);
            SelectedVehicle ??= Vehicles.FirstOrDefault();
            Message = $"{Vehicles.Count} mezzi · {Deadlines.Count} scadenze";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task AddVehicleAsync()
    {
        if (Plate.Trim().Length < 5 || Description.Trim().Length < 2)
        {
            Message = "Inserisci targa e descrizione del mezzo.";
            return;
        }
        int? km = null;
        if (!string.IsNullOrWhiteSpace(CurrentKm))
        {
            if (!int.TryParse(CurrentKm, out var parsed))
            {
                Message = "Chilometri non validi.";
                return;
            }
            km = parsed;
        }
        IsBusy = true;
        try
        {
            await _api.AddVehicleAsync(Plate, Description, Brand, Model, km);
            Plate = Description = Brand = Model = CurrentKm = string.Empty;
            IsBusy = false;
            await LoadAsync();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task AddDeadlineAsync()
    {
        if (SelectedVehicle is null || SelectedDeadlineType is null ||
            DeadlineDescription.Trim().Length < 2 || ExpiryDate is null)
        {
            Message = "Seleziona mezzo, tipo, descrizione e scadenza.";
            return;
        }
        IsBusy = true;
        try
        {
            await _api.AddVehicleDeadlineAsync(
                SelectedVehicle.Id, SelectedDeadlineType.Id, DeadlineDescription,
                Provider, DocumentNumber, ExpiryDate.Value);
            DeadlineDescription = Provider = DocumentNumber = string.Empty;
            ExpiryDate = null;
            IsBusy = false;
            await LoadAsync();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }
}
