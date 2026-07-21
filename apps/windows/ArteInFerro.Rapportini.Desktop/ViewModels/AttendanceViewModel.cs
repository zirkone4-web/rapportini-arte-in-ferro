using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class AttendanceViewModel : ObservableObject
{
    private static readonly CultureInfo Italian = CultureInfo.GetCultureInfo("it-IT");
    private readonly SupabaseApiService _api;

    [ObservableProperty] private AttendanceRow? _selectedDay;
    [ObservableProperty] private AttendanceEventRow? _selectedEvent;
    [ObservableProperty] private LookupItem? _selectedEmployee;
    [ObservableProperty] private LookupItem? _selectedHoursStatus;
    [ObservableProperty] private string _authorizedHoursText = string.Empty;
    [ObservableProperty] private string _eventDateTimeText = string.Empty;
    [ObservableProperty] private string _forceDateTimeText = DateTime.Now.ToString("dd/MM/yyyy HH:mm");
    [ObservableProperty] private string _reason = string.Empty;
    [ObservableProperty] private string _message = "Seleziona una riga per modificarla.";
    [ObservableProperty] private bool _isBusy;

    public AttendanceViewModel(SupabaseApiService api)
    {
        _api = api;
        HoursStatuses.Add(new LookupItem("autorizzata", "Autorizzata"));
        HoursStatuses.Add(new LookupItem("rifiutata", "Rifiutata"));
        HoursStatuses.Add(new LookupItem("da_autorizzare", "Da autorizzare"));
        SelectedHoursStatus = HoursStatuses[0];
        _ = LoadAsync();
    }

    public ObservableCollection<AttendanceRow> Days { get; } = [];
    public ObservableCollection<AttendanceEventRow> Events { get; } = [];
    public ObservableCollection<LookupItem> Employees { get; } = [];
    public ObservableCollection<LookupItem> HoursStatuses { get; } = [];

    partial void OnSelectedDayChanged(AttendanceRow? value)
    {
        if (value is null) return;
        AuthorizedHoursText = (value.AuthorizedHours ?? value.TotalHours)?.ToString("0.00", Italian) ?? string.Empty;
        SelectedHoursStatus = HoursStatuses.FirstOrDefault(x => x.Id == value.HoursStatus) ?? HoursStatuses[0];
        Reason = value.AdminNote ?? string.Empty;
        SelectedEmployee = Employees.FirstOrDefault(x => x.Id == value.EmployeeId);
        ForceDateTimeText = new DateTime(value.Day.Year, value.Day.Month, value.Day.Day,
            DateTime.Now.Hour, DateTime.Now.Minute, 0).ToString("dd/MM/yyyy HH:mm");
    }

    partial void OnSelectedEventChanged(AttendanceEventRow? value)
    {
        if (value is null) return;
        EventDateTimeText = value.RegisteredAt.LocalDateTime.ToString("dd/MM/yyyy HH:mm");
        SelectedEmployee = Employees.FirstOrDefault(x => x.Id == value.EmployeeId);
        Reason = string.Empty;
    }

    [RelayCommand]
    public async Task LoadAsync()
    {
        if (IsBusy) return;
        IsBusy = true;
        try
        {
            var days = await _api.GetAttendanceAsync();
            var events = await _api.GetAttendanceEventsAsync();
            var employees = await _api.GetEmployeesAsync();
            Days.Clear(); foreach (var row in days) Days.Add(row);
            Events.Clear(); foreach (var row in events) Events.Add(row);
            Employees.Clear(); foreach (var row in employees) Employees.Add(row);
            Message = $"{Days.Count} giornate · {Events.Count} timbrature";
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task SaveEventTimeAsync()
    {
        if (SelectedEvent is null) { Message = "Seleziona una timbratura."; return; }
        if (!TryDateTime(EventDateTimeText, out var value))
        { Message = "Data e ora non valide. Usa gg/mm/aaaa hh:mm."; return; }
        await RunAsync(() => _api.UpdateAttendanceTimeAsync(
            SelectedEvent.Id, new DateTimeOffset(value), Reason));
    }

    [RelayCommand]
    private async Task ApproveTransferAsync()
    {
        if (SelectedEvent is null) { Message = "Seleziona una timbratura."; return; }
        await RunAsync(() => _api.ReviewAttendanceAsync(SelectedEvent.Id, true, Reason));
    }

    [RelayCommand]
    private async Task RejectTransferAsync()
    {
        if (SelectedEvent is null) { Message = "Seleziona una timbratura."; return; }
        await RunAsync(() => _api.ReviewAttendanceAsync(SelectedEvent.Id, false, Reason));
    }

    [RelayCommand]
    private async Task AuthorizeHoursAsync()
    {
        if (SelectedDay is null || SelectedHoursStatus is null)
        { Message = "Seleziona una giornata."; return; }
        decimal? hours = null;
        if (!string.IsNullOrWhiteSpace(AuthorizedHoursText))
        {
            if (!decimal.TryParse(AuthorizedHoursText, NumberStyles.Number, Italian, out var parsed))
            { Message = "Ore autorizzate non valide."; return; }
            hours = parsed;
        }
        await RunAsync(() => _api.AuthorizeHoursAsync(
            SelectedDay, SelectedHoursStatus.Id, hours, Reason));
    }

    [RelayCommand]
    private Task ForceEntryAsync() => ForceAsync("entrata");

    [RelayCommand]
    private Task ForceExitAsync() => ForceAsync("uscita");

    private async Task ForceAsync(string type)
    {
        if (SelectedEmployee is null) { Message = "Seleziona un dipendente."; return; }
        if (!TryDateTime(ForceDateTimeText, out var value))
        { Message = "Data e ora forzata non valide."; return; }
        await RunAsync(() => _api.ForceAttendanceAsync(
            SelectedEmployee.Id, type, new DateTimeOffset(value), Reason));
    }

    [RelayCommand]
    private void OpenMap()
    {
        if (SelectedEvent?.Latitude is null || SelectedEvent.Longitude is null)
        { Message = "La timbratura selezionata non contiene una posizione GPS."; return; }
        var url = $"https://www.google.com/maps/search/?api=1&query=" +
                  $"{SelectedEvent.Latitude.Value.ToString(CultureInfo.InvariantCulture)}," +
                  SelectedEvent.Longitude.Value.ToString(CultureInfo.InvariantCulture);
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
            Message = "Modifica salvata e registrata nello storico.";
            Reason = string.Empty;
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    private static bool TryDateTime(string text, out DateTime value) =>
        DateTime.TryParse(text, Italian, DateTimeStyles.AssumeLocal, out value);
}
