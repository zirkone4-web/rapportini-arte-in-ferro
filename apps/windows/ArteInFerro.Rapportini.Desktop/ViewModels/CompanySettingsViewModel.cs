using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class CompanySettingsViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private string _companyName = string.Empty;
    [ObservableProperty] private string _vatNumber = string.Empty;
    [ObservableProperty] private string _fiscalCode = string.Empty;
    [ObservableProperty] private string _address = string.Empty;
    [ObservableProperty] private string _city = string.Empty;
    [ObservableProperty] private string _province = string.Empty;
    [ObservableProperty] private string _postalCode = string.Empty;
    [ObservableProperty] private string _email = string.Empty;
    [ObservableProperty] private string _pec = string.Empty;
    [ObservableProperty] private string _phone = string.Empty;
    [ObservableProperty] private string _website = string.Empty;
    [ObservableProperty] private string _contactName = string.Empty;
    [ObservableProperty] private string _contactRole = string.Empty;
    [ObservableProperty] private string _contactPhone = string.Empty;
    [ObservableProperty] private string _contactEmail = string.Empty;
    [ObservableProperty] private LookupItem? _selectedContactType;
    [ObservableProperty] private bool _visibleToEmployees = true;
    [ObservableProperty] private string _message = "Dati aziendali e rubrica dell’app.";
    [ObservableProperty] private bool _isBusy;

    public CompanySettingsViewModel(SupabaseApiService api)
    {
        _api = api;
        foreach (var item in new[]
        {
            new LookupItem("ufficio", "Ufficio"), new LookupItem("collaboratore", "Collaboratore"),
            new LookupItem("emergenza", "Emergenza"), new LookupItem("sicurezza", "Sicurezza")
        }) ContactTypes.Add(item);
        SelectedContactType = ContactTypes[0];
        _ = LoadAsync();
    }

    public ObservableCollection<LookupItem> ContactTypes { get; } = [];
    public ObservableCollection<CompanyContactRow> Contacts { get; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var company = await _api.GetCompanySettingsAsync();
            CompanyName = company.CompanyName; VatNumber = company.VatNumber ?? "";
            FiscalCode = company.FiscalCode ?? ""; Address = company.Address ?? "";
            City = company.City ?? ""; Province = company.Province ?? "";
            PostalCode = company.PostalCode ?? ""; Email = company.Email ?? "";
            Pec = company.Pec ?? ""; Phone = company.Phone ?? ""; Website = company.Website ?? "";
            var contacts = await _api.GetCompanyContactsAsync();
            Contacts.Clear(); foreach (var contact in contacts) Contacts.Add(contact);
            Message = $"{Contacts.Count} contatti registrati";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SaveCompanyAsync()
    {
        if (CompanyName.Trim().Length < 2) { Message = "Inserisci la ragione sociale."; return; }
        await RunAsync(async () =>
        {
            await _api.SaveCompanySettingsAsync(new CompanySettingsRow
            {
                CompanyName = CompanyName, VatNumber = VatNumber, FiscalCode = FiscalCode,
                Address = Address, City = City, Province = Province, PostalCode = PostalCode,
                Email = Email, Pec = Pec, Phone = Phone, Website = Website
            });
            Message = "Dati aziendali salvati.";
        });
    }

    [RelayCommand]
    private async Task AddContactAsync()
    {
        if (ContactName.Trim().Length < 2 || ContactRole.Trim().Length < 2 || SelectedContactType is null)
        { Message = "Inserisci nome, ruolo/reparto e tipo."; return; }
        await RunAsync(async () =>
        {
            await _api.AddCompanyContactAsync(ContactName, ContactRole, ContactPhone,
                ContactEmail, SelectedContactType.Id, VisibleToEmployees);
            ContactName = ContactRole = ContactPhone = ContactEmail = string.Empty;
            IsBusy = false; await LoadAsync();
        });
    }

    private async Task RunAsync(Func<Task> operation)
    {
        if (IsBusy) return; IsBusy = true;
        try { await operation(); } catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }
}
