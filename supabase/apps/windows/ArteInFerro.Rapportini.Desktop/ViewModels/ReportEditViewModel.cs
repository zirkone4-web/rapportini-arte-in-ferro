using System.Collections.ObjectModel;
using System.Globalization;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class ReportEditViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    private readonly ReportRow _original;
    private static readonly CultureInfo Italian = CultureInfo.GetCultureInfo("it-IT");

    [ObservableProperty] private string _place = string.Empty;
    [ObservableProperty] private string? _appointmentReference;
    [ObservableProperty] private LookupItem _selectedIntervention = null!;
    [ObservableProperty] private string _startText = string.Empty;
    [ObservableProperty] private string _endText = string.Empty;
    [ObservableProperty] private string _description = string.Empty;
    [ObservableProperty] private LookupItem _selectedStatus = null!;
    [ObservableProperty] private string? _adminNote;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

    public ReportEditViewModel(SupabaseApiService api, ReportRow report)
    {
        _api = api;
        _original = report;
        Place = report.Place;
        AppointmentReference = report.AppointmentReference;
        Description = report.Description;
        AdminNote = report.AdminNote;
        StartText = report.StartAt.LocalDateTime.ToString("dd/MM/yyyy HH:mm");
        EndText = report.EndAt?.LocalDateTime.ToString("dd/MM/yyyy HH:mm") ?? string.Empty;

        Interventions = new ObservableCollection<LookupItem>
        {
            new("montaggio_posa", "Montaggio / posa"),
            new("manutenzione_riparazione", "Manutenzione / riparazione"),
            new("sopralluogo", "Sopralluogo"),
            new("consegna_ritiro", "Consegna / ritiro"),
            new("lavorazione_officina", "Lavorazione in officina"),
            new("altro", "Altro")
        };
        Statuses = new ObservableCollection<LookupItem>
        {
            new("bozza", "Bozza"),
            new("inviato", "Inviato"),
            new("approvato", "Approvato"),
            new("respinto", "Respinto")
        };
        SelectedIntervention = Interventions.First(x => x.Id == report.InterventionType);
        SelectedStatus = Statuses.First(x => x.Id == report.Status);
    }

    public string Title => $"Rapportino · {_original.EmployeeName} · {_original.ClientName}";
    public ObservableCollection<LookupItem> Interventions { get; }
    public ObservableCollection<LookupItem> Statuses { get; }
    public event Action? Saved;

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (IsBusy) return;
        ErrorMessage = Validate(out var start, out var end);
        if (ErrorMessage is not null) return;

        IsBusy = true;
        try
        {
            var update = new ReportUpdate(
                Place,
                AppointmentReference,
                SelectedIntervention.Id,
                new DateTimeOffset(start),
                new DateTimeOffset(end),
                Description,
                SelectedStatus.Id,
                AdminNote);
            await _api.UpdateReportAsync(_original, update);
            Saved?.Invoke();
        }
        catch (Exception ex) when (ex is ApiException or ConcurrencyException or
                                   HttpRequestException or TaskCanceledException)
        {
            ErrorMessage = ex is TaskCanceledException ? "Il server non ha risposto in tempo." : ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private string? Validate(out DateTime start, out DateTime end)
    {
        start = default;
        end = default;
        if (string.IsNullOrWhiteSpace(Place)) return "Il luogo è obbligatorio.";
        if (string.IsNullOrWhiteSpace(Description)) return "La descrizione è obbligatoria.";
        if (!DateTime.TryParse(StartText, Italian, DateTimeStyles.AssumeLocal, out start))
            return "Data/ora inizio non valida. Usa gg/mm/aaaa hh:mm.";
        if (!DateTime.TryParse(EndText, Italian, DateTimeStyles.AssumeLocal, out end))
            return "Data/ora fine non valida. Usa gg/mm/aaaa hh:mm.";
        if (end <= start) return "La fine deve essere successiva all’inizio.";
        if (string.IsNullOrWhiteSpace(AdminNote) || AdminNote.Trim().Length < 3)
            return "Inserisci la motivazione della modifica nella nota ufficio.";
        return null;
    }
}
