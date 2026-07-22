using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class MasterDataViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private ClientRow? _selectedClient;
    [ObservableProperty] private WorksiteRow? _selectedWorksite;
    [ObservableProperty] private LookupItem? _selectedWorksiteClient;
    [ObservableProperty] private string _clientName = string.Empty;
    [ObservableProperty] private string _clientAddress = string.Empty;
    [ObservableProperty] private string _clientContact = string.Empty;
    [ObservableProperty] private string _clientPhone = string.Empty;
    [ObservableProperty] private bool _clientActive = true;
    [ObservableProperty] private string _worksiteName = string.Empty;
    [ObservableProperty] private string _worksiteAddress = string.Empty;
    [ObservableProperty] private string _latitudeText = string.Empty;
    [ObservableProperty] private string _longitudeText = string.Empty;
    [ObservableProperty] private string _radiusText = "200";
    [ObservableProperty] private string _worksiteNotes = string.Empty;
    [ObservableProperty] private bool _worksiteActive = true;
    [ObservableProperty] private string _reason = string.Empty;
    [ObservableProperty] private string _message = "Seleziona un cliente o un cantiere per modificarlo.";
    [ObservableProperty] private bool _isBusy;

    public MasterDataViewModel(SupabaseApiService api)
    {
        _api = api;
        _ = LoadAsync();
    }

    public ObservableCollection<ClientRow> Clients { get; } = [];
    public ObservableCollection<WorksiteRow> Worksites { get; } = [];
    public ObservableCollection<LookupItem> ClientChoices { get; } = [];

    partial void OnSelectedClientChanged(ClientRow? value)
    {
        if (value is null) return;
        ClientName = value.Name;
        ClientAddress = value.Address;
        ClientContact = value.Contact ?? string.Empty;
        ClientPhone = value.Phone ?? string.Empty;
        ClientActive = value.Active;
        Reason = string.Empty;
    }

    partial void OnSelectedWorksiteChanged(WorksiteRow? value)
    {
        if (value is null) return;
        SelectedWorksiteClient = ClientChoices.FirstOrDefault(x => x.Id == value.ClientId);
        WorksiteName = value.Name;
        WorksiteAddress = value.Address;
        LatitudeText = value.Latitude.ToString(CultureInfo.InvariantCulture);
        LongitudeText = value.Longitude.ToString(CultureInfo.InvariantCulture);
        RadiusText = value.RadiusMeters.ToString(CultureInfo.InvariantCulture);
        WorksiteNotes = value.Notes ?? string.Empty;
        WorksiteActive = value.Active;
        Reason = string.Empty;
    }

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var clients = await _api.GetClientRowsAsync();
            var worksites = await _api.GetWorksitesAsync();
            Clients.Clear(); foreach (var row in clients) Clients.Add(row);
            Worksites.Clear(); foreach (var row in worksites) Worksites.Add(row);
            ClientChoices.Clear();
            foreach (var row in clients.Where(x => x.Active))
                ClientChoices.Add(new LookupItem(row.Id, row.Name));
            SelectedWorksiteClient ??= ClientChoices.FirstOrDefault();
            Message = $"{Clients.Count} clienti · {Worksites.Count} cantieri";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private void NewClient()
    {
        SelectedClient = null;
        ClientName = ClientAddress = ClientContact = ClientPhone = string.Empty;
        ClientActive = true;
        Reason = string.Empty;
        Message = "Inserisci i dati del nuovo cliente.";
    }

    [RelayCommand]
    private async Task SaveClientAsync()
    {
        if (ClientName.Trim().Length < 2 || ClientAddress.Trim().Length < 2)
        { Message = "Inserisci ragione sociale e indirizzo."; return; }
        await RunAsync(() => _api.SaveClientAsync(SelectedClient, ClientName,
            ClientAddress, ClientContact, ClientPhone, ClientActive, Reason));
    }

    [RelayCommand]
    private void NewWorksite()
    {
        SelectedWorksite = null;
        SelectedWorksiteClient = ClientChoices.FirstOrDefault();
        WorksiteName = WorksiteAddress = LatitudeText = LongitudeText = WorksiteNotes = string.Empty;
        RadiusText = "200";
        WorksiteActive = true;
        Reason = string.Empty;
        Message = "Inserisci i dati e le coordinate del nuovo cantiere.";
    }

    [RelayCommand]
    private async Task SaveWorksiteAsync()
    {
        if (SelectedWorksiteClient is null)
        { Message = "Seleziona il cliente del cantiere."; return; }
        if (!TryDecimal(LatitudeText, out var latitude) || !TryDecimal(LongitudeText, out var longitude) ||
            !int.TryParse(RadiusText, out var radius))
        { Message = "Coordinate o raggio non validi."; return; }
        await RunAsync(() => _api.SaveWorksiteAsync(SelectedWorksite,
            SelectedWorksiteClient.Id, WorksiteName, WorksiteAddress,
            latitude, longitude, radius, WorksiteActive, WorksiteNotes, Reason));
    }

    [RelayCommand]
    private void OpenWorksiteMap()
    {
        if (!TryDecimal(LatitudeText, out var latitude) || !TryDecimal(LongitudeText, out var longitude))
        { Message = "Coordinate non valide."; return; }
        var url = "https://www.google.com/maps/search/?api=1&query=" +
                  latitude.ToString(CultureInfo.InvariantCulture) + "," +
                  longitude.ToString(CultureInfo.InvariantCulture);
        Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
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
            Message = "Modifica salvata e registrata nello storico.";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    private static bool TryDecimal(string text, out decimal value) =>
        decimal.TryParse(text.Replace(',', '.'), NumberStyles.Number,
            CultureInfo.InvariantCulture, out value);
}
