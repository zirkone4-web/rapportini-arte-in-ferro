using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class EmployeeDocumentsViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private LookupItem? _selectedEmployee;
    [ObservableProperty] private string _category = "corso";
    [ObservableProperty] private string _title = string.Empty;
    [ObservableProperty] private string _issuer = string.Empty;
    [ObservableProperty] private string _documentNumber = string.Empty;
    [ObservableProperty] private DateTime? _issueDate = DateTime.Today;
    [ObservableProperty] private DateTime? _expiryDate;
    [ObservableProperty] private string _fitness = string.Empty;
    [ObservableProperty] private string _documentUrl = string.Empty;
    [ObservableProperty] private bool _visibleToEmployee = true;
    [ObservableProperty] private string _message = "Inserisci corso, patentino, visita o incarico.";
    [ObservableProperty] private bool _isBusy;

    public EmployeeDocumentsViewModel(SupabaseApiService api)
    {
        _api = api;
        Categories.Add(new LookupItem("corso", "Corso"));
        Categories.Add(new LookupItem("patentino", "Patentino / abilitazione"));
        Categories.Add(new LookupItem("visita_medica", "Visita medica / idoneità"));
        Categories.Add(new LookupItem("incarico_sicurezza", "Incarico sicurezza"));
        Categories.Add(new LookupItem("altro", "Altro"));
        SelectedCategory = Categories[0];
        _ = LoadAsync();
    }

    [ObservableProperty] private LookupItem? _selectedCategory;
    public ObservableCollection<LookupItem> Employees { get; } = [];
    public ObservableCollection<LookupItem> Categories { get; } = [];
    public ObservableCollection<EmployeeDocumentRow> Documents { get; } = [];

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var employees = await _api.GetEmployeesAsync();
            var documents = await _api.GetEmployeeDocumentsAsync();
            Employees.Clear();
            foreach (var item in employees) Employees.Add(item);
            SelectedEmployee ??= Employees.FirstOrDefault();
            Documents.Clear();
            foreach (var item in documents) Documents.Add(item);
            Message = $"{Documents.Count} documenti presenti";
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            Message = ex.Message;
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (SelectedEmployee is null || SelectedCategory is null || Title.Trim().Length < 2)
        {
            Message = "Seleziona dipendente, categoria e titolo.";
            return;
        }
        if (IssueDate is not null && ExpiryDate is not null && ExpiryDate < IssueDate)
        {
            Message = "La scadenza non può precedere il rilascio.";
            return;
        }
        IsBusy = true;
        try
        {
            await _api.AddEmployeeDocumentAsync(
                SelectedEmployee.Id, SelectedCategory.Id, Title, Issuer,
                DocumentNumber, IssueDate, ExpiryDate, Fitness, DocumentUrl,
                VisibleToEmployee);
            Title = Issuer = DocumentNumber = Fitness = DocumentUrl = string.Empty;
            ExpiryDate = null;
            Message = "Documento salvato e disponibile nell’app del dipendente.";
            IsBusy = false;
            await LoadAsync();
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            Message = ex.Message;
        }
        finally { IsBusy = false; }
    }
}
