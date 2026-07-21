using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class CompanyCertificationsViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private LookupItem? _selectedType;
    [ObservableProperty] private string _title = string.Empty;
    [ObservableProperty] private string _issuer = string.Empty;
    [ObservableProperty] private string _certificateNumber = string.Empty;
    [ObservableProperty] private DateTime? _issueDate;
    [ObservableProperty] private DateTime? _expiryDate;
    [ObservableProperty] private string _documentUrl = string.Empty;
    [ObservableProperty] private string _message = "Certificazioni e qualifiche aziendali.";
    [ObservableProperty] private bool _isBusy;

    public CompanyCertificationsViewModel(SupabaseApiService api)
    {
        _api = api;
        foreach (var item in new[]
        {
            new LookupItem("rina", "RINA"), new LookupItem("iso_9001", "ISO 9001"),
            new LookupItem("en_1090", "EN 1090"), new LookupItem("iso_3834", "ISO 3834"),
            new LookupItem("qualifica_saldatura", "Qualifica saldatura"),
            new LookupItem("soa", "SOA"), new LookupItem("altro", "Altro")
        }) Types.Add(item);
        SelectedType = Types[0];
        _ = LoadAsync();
    }

    public ObservableCollection<LookupItem> Types { get; } = [];
    public ObservableCollection<CompanyCertificationRow> Certifications { get; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var rows = await _api.GetCompanyCertificationsAsync();
            Certifications.Clear();
            foreach (var row in rows) Certifications.Add(row);
            Message = $"{Certifications.Count} certificazioni registrate";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task AddAsync()
    {
        if (SelectedType is null || Title.Trim().Length < 2)
        {
            Message = "Seleziona il tipo e inserisci il titolo.";
            return;
        }
        IsBusy = true;
        try
        {
            await _api.AddCompanyCertificationAsync(SelectedType.Id, Title, Issuer,
                CertificateNumber, IssueDate, ExpiryDate, DocumentUrl);
            Title = Issuer = CertificateNumber = DocumentUrl = string.Empty;
            IssueDate = ExpiryDate = null;
            IsBusy = false;
            await LoadAsync();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }
}
