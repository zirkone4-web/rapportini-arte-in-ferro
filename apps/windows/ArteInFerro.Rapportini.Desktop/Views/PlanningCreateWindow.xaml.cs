using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class PlanningCreateWindow : Window
{
    private readonly SupabaseApiService _api;
    private readonly bool _isPlanned;
    private readonly List<LookupItem> _employees = [];
    private readonly List<LookupItem> _clients = [];
    private readonly List<LookupItem> _vehicles = [];
    private readonly List<PlanningWorksiteItem> _worksites = [];

    public PlanningCreateWindow(SupabaseApiService api, bool isPlanned)
    {
        InitializeComponent();
        _api = api;
        _isPlanned = isPlanned;
        WorkDatePicker.SelectedDate = isPlanned ? DateTime.Today.AddDays(1) : DateTime.Today;
        HeadingText.Text = isPlanned ? "Pianifica giornata di lavoro" : "Nuovo rapportino amministrativo";
        SubheadingText.Text = isPlanned
            ? "Crea un lavoro singolo o di squadra e rendilo disponibile nell'app dei dipendenti."
            : "Crea dall'ufficio un rapportino in stato bozza e assegnalo al dipendente.";
        SaveButton.Content = isPlanned ? "SALVA E ASSEGNA" : "CREA RAPPORTINO";
    }

    private async void WindowLoaded(object sender, RoutedEventArgs e)
    {
        IsEnabled = false;
        StatusText.Text = "Caricamento anagrafiche…";
        try
        {
            _employees.AddRange(await _api.GetEmployeesAsync());
            _clients.AddRange(await _api.GetClientsAsync());
            _vehicles.AddRange(await _api.GetVehicleLookupAsync());
            _worksites.AddRange(await _api.GetPlanningWorksitesAsync());

            ResponsibleCombo.ItemsSource = _employees;
            ClientCombo.ItemsSource = _clients;
            VehicleCombo.ItemsSource = _vehicles;
            WorksiteCombo.ItemsSource = _worksites;
            CollaboratorsList.ItemsSource = _employees;
            InterventionCombo.ItemsSource = new[]
            {
                new LookupItem("montaggio_posa", "Montaggio / posa"),
                new LookupItem("manutenzione_riparazione", "Manutenzione / riparazione"),
                new LookupItem("sopralluogo", "Sopralluogo"),
                new LookupItem("consegna_ritiro", "Consegna / ritiro"),
                new LookupItem("lavorazione_officina", "Lavorazione in officina"),
                new LookupItem("altro", "Altro")
            };
            InterventionCombo.SelectedIndex = 0;
            StatusText.Text = "Digita le prime lettere per trovare cliente, dipendente, cantiere o mezzo.";
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            MessageBox.Show(ex.Message, "Errore caricamento", MessageBoxButton.OK, MessageBoxImage.Error);
            Close();
        }
        finally
        {
            IsEnabled = true;
        }
    }

    private void WorksiteChanged(object sender, SelectionChangedEventArgs e)
    {
        if (WorksiteCombo.SelectedItem is not PlanningWorksiteItem worksite) return;
        PlaceText.Text = string.IsNullOrWhiteSpace(worksite.Address)
            ? worksite.Name
            : $"{worksite.Name} - {worksite.Address}";
        var client = _clients.FirstOrDefault(item => item.Id == worksite.ClientId);
        if (client is not null) ClientCombo.SelectedItem = client;
    }

    private async void SaveClick(object sender, RoutedEventArgs e)
    {
        var employee = ResolveLookup(ResponsibleCombo, _employees);
        var client = ResolveLookup(ClientCombo, _clients);
        var vehicle = ResolveLookup(VehicleCombo, _vehicles, optional: true);
        var intervention = InterventionCombo.SelectedItem as LookupItem;

        if (employee is null || client is null || intervention is null)
        {
            MessageBox.Show("Seleziona responsabile, cliente e tipo di intervento.",
                "Dati mancanti", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        if (WorkDatePicker.SelectedDate is not DateTime date ||
            !TryBuildDateTime(date, StartTimeText.Text, out var startAt) ||
            !TryBuildDateTime(date, EndTimeText.Text, out var endAt) ||
            endAt <= startAt)
        {
            MessageBox.Show("Controlla data e orari. Usa il formato HH:mm.",
                "Orari non validi", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        if (PlaceText.Text.Trim().Length < 2 || DescriptionText.Text.Trim().Length < 3)
        {
            MessageBox.Show("Inserisci luogo e attività da eseguire.",
                "Dati mancanti", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var collaborators = CollaboratorsList.SelectedItems
            .Cast<LookupItem>()
            .Select(item => item.Id)
            .Where(id => id != employee.Id)
            .Distinct()
            .ToList();

        var request = new AdministrativeReportRequest
        {
            EmployeeId = employee.Id,
            ClientId = client.Id,
            VehicleId = vehicle?.Id,
            VehiclePlate = vehicle is null ? null : VehiclePlate(vehicle.Label),
            Place = PlaceText.Text.Trim(),
            AppointmentReference = null,
            InterventionType = intervention.Id,
            StartAt = startAt,
            EndAt = endAt,
            Description = DescriptionText.Text.Trim(),
            PlanningNotes = string.IsNullOrWhiteSpace(PlanningNotesText.Text)
                ? null
                : PlanningNotesText.Text.Trim(),
            IsPlanned = _isPlanned,
            CollaboratorIds = collaborators
        };

        IsEnabled = false;
        StatusText.Text = "Salvataggio su Supabase…";
        try
        {
            await _api.CreateAdministrativeReportAsync(request);
            MessageBox.Show(
                _isPlanned
                    ? "Lavoro assegnato correttamente alla squadra."
                    : "Rapportino amministrativo creato in bozza.",
                "Operazione completata", MessageBoxButton.OK, MessageBoxImage.Information);
            DialogResult = true;
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            MessageBox.Show(ex.Message, "Salvataggio non riuscito", MessageBoxButton.OK,
                MessageBoxImage.Error);
            StatusText.Text = ex.Message;
            IsEnabled = true;
        }
    }

    private static LookupItem? ResolveLookup(
        ComboBox combo,
        IReadOnlyList<LookupItem> items,
        bool optional = false)
    {
        if (combo.SelectedItem is LookupItem selected) return selected;
        var text = combo.Text.Trim();
        if (text.Length == 0) return optional ? null : null;
        return items.FirstOrDefault(item => item.Label.StartsWith(
                   text, StringComparison.CurrentCultureIgnoreCase))
               ?? items.FirstOrDefault(item => item.Label.Contains(
                   text, StringComparison.CurrentCultureIgnoreCase));
    }

    private static bool TryBuildDateTime(DateTime date, string time, out DateTimeOffset value)
    {
        value = default;
        if (!DateTime.TryParseExact(time.Trim(), "HH:mm", CultureInfo.InvariantCulture,
                DateTimeStyles.None, out var parsed)) return false;
        var local = new DateTime(date.Year, date.Month, date.Day, parsed.Hour, parsed.Minute, 0,
            DateTimeKind.Local);
        value = new DateTimeOffset(local);
        return true;
    }

    private static string VehiclePlate(string label)
    {
        var separator = label.IndexOf('·');
        return (separator >= 0 ? label[..separator] : label).Trim().ToUpperInvariant();
    }

    private void CancelClick(object sender, RoutedEventArgs e) => Close();
}