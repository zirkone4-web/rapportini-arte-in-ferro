using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class DashboardViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    private readonly ExportService _exports;
    private readonly WindowsFileSavePicker _filePicker = new();
    private readonly List<ReportRow> _allReports = [];

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private string _statusMessage = "Caricamento dati…";

    [ObservableProperty]
    private DateTime? _dateFrom = DateTime.Today.AddDays(-30);

    [ObservableProperty]
    private DateTime? _dateTo = DateTime.Today;

    [ObservableProperty]
    private LookupItem? _selectedEmployee;

    [ObservableProperty]
    private LookupItem? _selectedClient;

    [ObservableProperty]
    private LookupItem? _selectedStatus;

    [ObservableProperty]
    private ReportRow? _selectedReport;

    public DashboardViewModel(SupabaseApiService api, ExportService exports)
    {
        _api = api;
        _exports = exports;
        Employees.Add(new LookupItem(string.Empty, "Tutti i dipendenti"));
        Clients.Add(new LookupItem(string.Empty, "Tutti i clienti"));
        Statuses.Add(new LookupItem(string.Empty, "Tutti gli stati"));
        Statuses.Add(new LookupItem("bozza", "Bozza"));
        Statuses.Add(new LookupItem("inviato", "Inviato"));
        Statuses.Add(new LookupItem("approvato", "Approvato"));
        Statuses.Add(new LookupItem("respinto", "Respinto"));
        SelectedEmployee = Employees[0];
        SelectedClient = Clients[0];
        SelectedStatus = Statuses[0];
        _ = LoadAsync();
    }

    public string AdminName => _api.Session.FullName;
    public ObservableCollection<ReportRow> Reports { get; } = [];
    public ObservableCollection<AttendanceRow> Attendance { get; } = [];
    public ObservableCollection<DeadlineRow> Deadlines { get; } = [];
    public ObservableCollection<LookupItem> Employees { get; } = [];
    public ObservableCollection<LookupItem> Clients { get; } = [];
    public ObservableCollection<LookupItem> Statuses { get; } = [];

    public event Action<ReportRow>? EditRequested;

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        StatusMessage = "Aggiornamento dal cloud…";
        try
        {
            var employees = await _api.GetEmployeesAsync();
            var clients = await _api.GetClientsAsync();
            var reports = await _api.GetReportsAsync();
            var attendance = await _api.GetAttendanceAsync();
            var deadlines = await _api.GetDeadlinesAsync();

            var employeeId = SelectedEmployee?.Id;
            var clientId = SelectedClient?.Id;
            Employees.Clear();
            Employees.Add(new LookupItem(string.Empty, "Tutti i dipendenti"));
            foreach (var item in employees) Employees.Add(item);
            Clients.Clear();
            Clients.Add(new LookupItem(string.Empty, "Tutti i clienti"));
            foreach (var item in clients) Clients.Add(item);
            SelectedEmployee = Employees.FirstOrDefault(x => x.Id == employeeId) ?? Employees[0];
            SelectedClient = Clients.FirstOrDefault(x => x.Id == clientId) ?? Clients[0];

            _allReports.Clear();
            _allReports.AddRange(reports);
            Attendance.Clear();
            foreach (var row in attendance) Attendance.Add(row);
            Deadlines.Clear();
            foreach (var row in deadlines) Deadlines.Add(row);
            ApplyFilters();
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            StatusMessage = ex is TaskCanceledException
                ? "Timeout durante l’aggiornamento."
                : ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void ApplyFilters()
    {
        var result = _allReports.AsEnumerable();
        if (DateFrom is not null)
            result = result.Where(r => r.StartAt.LocalDateTime >= DateFrom.Value.Date);
        if (DateTo is not null)
            result = result.Where(r => r.StartAt.LocalDateTime < DateTo.Value.Date.AddDays(1));
        if (!string.IsNullOrEmpty(SelectedEmployee?.Id))
            result = result.Where(r => r.EmployeeId == SelectedEmployee.Id);
        if (!string.IsNullOrEmpty(SelectedClient?.Id))
            result = result.Where(r => r.ClientId == SelectedClient.Id);
        if (!string.IsNullOrEmpty(SelectedStatus?.Id))
            result = result.Where(r => r.Status == SelectedStatus.Id);

        Reports.Clear();
        foreach (var report in result.OrderByDescending(r => r.StartAt)) Reports.Add(report);
        StatusMessage = $"{Reports.Count} rapportini visualizzati";
    }

    [RelayCommand]
    private void Edit()
    {
        if (SelectedReport is null)
        {
            StatusMessage = "Seleziona un rapportino.";
            return;
        }
        EditRequested?.Invoke(SelectedReport);
    }

    [RelayCommand]
    private async Task ApproveAsync()
    {
        if (SelectedReport is null)
        {
            StatusMessage = "Seleziona un rapportino.";
            return;
        }
        if (SelectedReport.Status != "inviato")
        {
            StatusMessage = "Puoi approvare direttamente solo un rapportino inviato.";
            return;
        }
        await RunBusyAsync(async () =>
        {
            await _api.SetStatusAsync(
                SelectedReport,
                "approvato",
                SelectedReport.AdminNote);
            StatusMessage = "Rapportino approvato.";
            await LoadAsyncAfterBusy();
        });
    }

    [RelayCommand]
    private async Task ExportExcelAsync()
    {
        if (Reports.Count == 0)
        {
            StatusMessage = "Non ci sono dati da esportare.";
            return;
        }
        var path = _filePicker.PickExcelPath();
        if (path is null) return;
        await RunBusyAsync(async () =>
        {
            await _exports.ExportExcelAsync(path, Reports.ToList());
            StatusMessage = $"Excel salvato in {path}";
        });
    }

    [RelayCommand]
    private async Task ExportPdfAsync()
    {
        if (SelectedReport is null)
        {
            StatusMessage = "Seleziona il rapportino da esportare.";
            return;
        }
        var path = _filePicker.PickPdfPath(SelectedReport.Id);
        if (path is null) return;
        await RunBusyAsync(async () =>
        {
            await _exports.ExportPdfAsync(path, SelectedReport);
            StatusMessage = $"PDF salvato in {path}";
        });
    }

    [RelayCommand]
    private async Task ExportAttendanceAsync()
    {
        if (Attendance.Count == 0)
        {
            StatusMessage = "Non ci sono presenze da esportare.";
            return;
        }
        var path = _filePicker.PickAttendanceExcelPath();
        if (path is null) return;
        await RunBusyAsync(async () =>
        {
            await _exports.ExportAttendanceExcelAsync(path, Attendance.ToList());
            StatusMessage = $"Presenze e straordinari salvati in {path}";
        });
    }

    public Task RefreshAfterEditAsync() => LoadAsync();

    private async Task RunBusyAsync(Func<Task> action)
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            await action();
        }
        catch (Exception ex) when (ex is ApiException or ConcurrencyException or
                                   HttpRequestException or IOException or TaskCanceledException)
        {
            StatusMessage = ex is TaskCanceledException ? "Operazione scaduta." : ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task LoadAsyncAfterBusy()
    {
        IsBusy = false;
        await LoadAsync();
        IsBusy = true;
    }
}
