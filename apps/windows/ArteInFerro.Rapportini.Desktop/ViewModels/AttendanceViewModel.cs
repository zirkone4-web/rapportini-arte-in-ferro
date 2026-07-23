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
    private List<AttendanceRow> _allDays = [];
    private List<AttendanceEventRow> _allEvents = [];
    private List<LookupItem> _allEmployees = [];

    [ObservableProperty] private AttendanceGridRow? _selectedGridRow;
    [ObservableProperty] private AttendanceRow? _selectedDay;
    [ObservableProperty] private AttendanceEventRow? _selectedEvent;
    [ObservableProperty] private LookupItem? _selectedEmployee;
    [ObservableProperty] private LookupItem? _selectedHoursStatus;
    [ObservableProperty] private string _authorizedHoursText = string.Empty;
    [ObservableProperty] private string _eventDateTimeText = string.Empty;
    [ObservableProperty] private string _forceDateTimeText = DateTime.Now.ToString("dd/MM/yyyy HH:mm");
    [ObservableProperty] private string _reason = string.Empty;
    [ObservableProperty] private string _message = "Caricamento presenze…";
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private DateTime _periodDate = DateTime.Today;
    [ObservableProperty] private string _periodMode = "day";
    [ObservableProperty] private string _periodLabel = string.Empty;

    public AttendanceViewModel(SupabaseApiService api)
    {
        _api = api;
        HoursStatuses.Add(new LookupItem("autorizzata", "Autorizzata"));
        HoursStatuses.Add(new LookupItem("rifiutata", "Rifiutata"));
        HoursStatuses.Add(new LookupItem("da_autorizzare", "Da autorizzare"));
        SelectedHoursStatus = HoursStatuses[0];
        _ = LoadAsync();
    }

    public ObservableCollection<AttendanceGridRow> GridRows { get; } = [];
    public ObservableCollection<AttendanceEventRow> Events { get; } = [];
    public ObservableCollection<LookupItem> Employees { get; } = [];
    public ObservableCollection<LookupItem> HoursStatuses { get; } = [];

    partial void OnSelectedGridRowChanged(AttendanceGridRow? value)
    {
        if (value is null) return;
        SelectedEmployee = Employees.FirstOrDefault(x => x.Id == value.EmployeeId);
        var day = value.ReferenceDay ?? PeriodDate.Date;
        SelectedDay = _allDays.FirstOrDefault(x =>
            x.EmployeeId == value.EmployeeId && x.Day.Date == day.Date);
        if (SelectedDay is null)
        {
            AuthorizedHoursText = string.Empty;
            SelectedHoursStatus = HoursStatuses[0];
            Reason = string.Empty;
        }
    }

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
            _allDays = (await _api.GetAttendanceAsync()).ToList();
            _allEvents = (await _api.GetAttendanceEventsAsync()).ToList();
            _allEmployees = (await _api.GetEmployeesAsync()).ToList();
            Employees.Clear();
            foreach (var row in _allEmployees) Employees.Add(row);
            RefreshPeriod();
        }
        catch (Exception ex) { Message = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private void SetPeriod(string mode)
    {
        if (mode is not ("day" or "week" or "month" or "year")) return;
        PeriodMode = mode;
        RefreshPeriod();
    }

    [RelayCommand]
    private void PreviousPeriod()
    {
        PeriodDate = PeriodMode switch
        {
            "week" => PeriodDate.AddDays(-7),
            "month" => PeriodDate.AddMonths(-1),
            "year" => PeriodDate.AddYears(-1),
            _ => PeriodDate.AddDays(-1)
        };
        RefreshPeriod();
    }

    [RelayCommand]
    private void NextPeriod()
    {
        PeriodDate = PeriodMode switch
        {
            "week" => PeriodDate.AddDays(7),
            "month" => PeriodDate.AddMonths(1),
            "year" => PeriodDate.AddYears(1),
            _ => PeriodDate.AddDays(1)
        };
        RefreshPeriod();
    }

    [RelayCommand]
    private void Today()
    {
        PeriodDate = DateTime.Today;
        RefreshPeriod();
    }

    private void RefreshPeriod()
    {
        var (start, end) = PeriodRange();
        PeriodLabel = PeriodMode switch
        {
            "week" => $"{start:dd/MM/yyyy} – {end.AddDays(-1):dd/MM/yyyy}",
            "month" => start.ToString("MMMM yyyy", Italian),
            "year" => start.ToString("yyyy", Italian),
            _ => start.ToString("dddd dd MMMM yyyy", Italian)
        };

        var selectedEmployeeId = SelectedGridRow?.EmployeeId;
        var periodDays = _allDays
            .Where(row => row.Day.Date >= start && row.Day.Date < end)
            .ToList();
        var periodEvents = _allEvents
            .Where(row => row.RegisteredAt.LocalDateTime.Date >= start &&
                          row.RegisteredAt.LocalDateTime.Date < end)
            .OrderByDescending(row => row.RegisteredAt)
            .ToList();

        GridRows.Clear();
        var expectedDays = CountExpectedDays(start, end);
        foreach (var employee in _allEmployees.OrderBy(item => item.Label))
        {
            var rows = periodDays.Where(row => row.EmployeeId == employee.Id).ToList();
            var events = periodEvents.Where(row => row.EmployeeId == employee.Id).ToList();
            var workedDays = rows.Count(row => row.FirstEntry is not null || (row.TotalHours ?? 0) > 0);
            var firstEntry = events.Where(row => row.Type == "entrata")
                .Select(row => (DateTimeOffset?)row.RegisteredAt).Min();
            var lastExit = events.Where(row => row.Type == "uscita")
                .Select(row => (DateTimeOffset?)row.RegisteredAt).Max();
            var totalHours = rows.Sum(row => row.TotalHours ?? 0);
            var compensation = rows.Sum(row => row.OvertimeHours ??
                Math.Max(0, (row.TotalHours ?? 0) - 8));
            var pendingTransfers = rows.Count(row => row.HasPendingTransfer);
            var status = StatusForPeriod(rows, events, start, end);

            GridRows.Add(new AttendanceGridRow
            {
                EmployeeId = employee.Id,
                EmployeeName = employee.Label,
                AccessLabel = "Accesso attivo",
                StatusLabel = status,
                FirstEntry = firstEntry,
                LastExit = lastExit,
                WorkedDays = workedDays,
                MissingDays = Math.Max(0, expectedDays - workedDays),
                TotalHours = totalHours,
                CompensationHours = compensation,
                PendingTransfers = pendingTransfers,
                ReferenceDay = PeriodMode == "day" ? start : rows.FirstOrDefault()?.Day
            });
        }

        Events.Clear();
        foreach (var row in periodEvents) Events.Add(row);
        SelectedGridRow = GridRows.FirstOrDefault(x => x.EmployeeId == selectedEmployeeId)
            ?? GridRows.FirstOrDefault();
        Message = $"{GridRows.Count} dipendenti · {periodEvents.Count} timbrature · periodo {PeriodLabel}";
    }

    private string StatusForPeriod(
        IReadOnlyCollection<AttendanceRow> rows,
        IReadOnlyCollection<AttendanceEventRow> events,
        DateTime start,
        DateTime end)
    {
        if (rows.Any(row => row.HasRejectedAttendance)) return "Da verificare";
        if (PeriodMode != "day")
        {
            var worked = rows.Count(row => row.FirstEntry is not null || (row.TotalHours ?? 0) > 0);
            return worked == 0 ? "Senza timbrature" : $"{worked} giorni lavorati";
        }
        var latest = events.OrderByDescending(row => row.RegisteredAt).FirstOrDefault();
        if (latest is null) return start.Date > DateTime.Today ? "Non ancora iniziato" : "Senza timbrature";
        return latest.Type == "entrata" ? "Presente" : "Uscito";
    }

    private (DateTime Start, DateTime End) PeriodRange()
    {
        var date = PeriodDate.Date;
        return PeriodMode switch
        {
            "week" => (date.AddDays(-(((int)date.DayOfWeek + 6) % 7)),
                date.AddDays(-(((int)date.DayOfWeek + 6) % 7)).AddDays(7)),
            "month" => (new DateTime(date.Year, date.Month, 1),
                new DateTime(date.Year, date.Month, 1).AddMonths(1)),
            "year" => (new DateTime(date.Year, 1, 1), new DateTime(date.Year + 1, 1, 1)),
            _ => (date, date.AddDays(1))
        };
    }

    private static int CountExpectedDays(DateTime start, DateTime end)
    {
        var effectiveEnd = end > DateTime.Today.AddDays(1) ? DateTime.Today.AddDays(1) : end;
        var count = 0;
        for (var day = start; day < effectiveEnd; day = day.AddDays(1))
            if (day.DayOfWeek is not (DayOfWeek.Saturday or DayOfWeek.Sunday)) count++;
        return count;
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
        if (PeriodMode != "day")
        { Message = "L'autorizzazione delle ore si effettua nella visualizzazione Giorno."; return; }
        if (SelectedDay is null || SelectedHoursStatus is null)
        { Message = "Il dipendente selezionato non ha timbrature nella giornata."; return; }
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
