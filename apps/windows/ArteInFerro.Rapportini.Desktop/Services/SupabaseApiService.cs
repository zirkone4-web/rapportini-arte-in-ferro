using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using ArteInFerro.Rapportini.Desktop.Models;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class SupabaseApiService
{
    private readonly HttpClient _http;
    private readonly AppSettings _settings;
    private readonly AppSession _session;
    private readonly JsonSerializerOptions _json = new(JsonSerializerDefaults.Web);

    public SupabaseApiService(HttpClient http, AppSettings settings, AppSession session)
    {
        _http = http;
        _settings = settings;
        _session = session;
    }

    public AppSession Session => _session;

    public async Task<IReadOnlyList<ReportRow>> GetReportsAsync(
        CancellationToken cancellationToken = default)
    {
        const string select = "id,dipendente_id,cliente_id,luogo,rif_appuntamento," +
            "mezzo_id,targa_mezzo,km_mezzo," +
            "tipologia_intervento,data_ora_inizio,data_ora_fine,ore_totali,descrizione," +
            "firma_cliente_url,gps_latitudine,gps_longitudine,gps_precisione_metri," +
            "gps_rilevato_at,stato,nota_amministratore,created_at,updated_at,versione," +
            "dipendente:utenti!rapportini_dipendente_id_fkey(nome_cognome)," +
            "cliente:clienti!rapportini_cliente_id_fkey(ragione_sociale)";
        var uri = RestUri("rapportini") +
                  $"?select={Uri.EscapeDataString(select)}&order=data_ora_inizio.desc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
    }

    public async Task<IReadOnlyList<LookupItem>> GetEmployeesAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("utenti") + "?select=id,nome_cognome&attivo=eq.true&order=nome_cognome",
            null,
            cancellationToken);
        var rows = JsonSerializer.Deserialize<List<UserLookup>>(payload, _json) ?? [];
        return rows.Select(row => new LookupItem(row.Id, row.Name)).ToList();
    }

    public async Task<IReadOnlyList<LookupItem>> GetClientsAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("clienti") + "?select=id,ragione_sociale&order=ragione_sociale",
            null,
            cancellationToken);
        var rows = JsonSerializer.Deserialize<List<ClientLookup>>(payload, _json) ?? [];
        return rows.Select(row => new LookupItem(row.Id, row.Name)).ToList();
    }

    public async Task<IReadOnlyList<ClientRow>> GetClientRowsAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get,
            RestUri("clienti") +
            "?select=id,ragione_sociale,indirizzo,referente,telefono,attivo&order=ragione_sociale",
            null, cancellationToken);
        return JsonSerializer.Deserialize<List<ClientRow>>(payload, _json) ?? [];
    }

    public async Task SaveClientAsync(
        ClientRow? original,
        string name,
        string address,
        string? contact,
        string? phone,
        bool active,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        var body = new Dictionary<string, object?>
        {
            ["ragione_sociale"] = name.Trim(),
            ["indirizzo"] = address.Trim(),
            ["referente"] = EmptyToNull(contact),
            ["telefono"] = EmptyToNull(phone),
            ["attivo"] = active,
            ["motivo_modifica"] = reason.Trim()
        };
        var method = original is null ? HttpMethod.Post : HttpMethod.Patch;
        var uri = RestUri("clienti") + (original is null
            ? string.Empty
            : $"?id=eq.{Uri.EscapeDataString(original.Id)}");
        await SendAsync(method, uri, body, cancellationToken);
    }

    public async Task<IReadOnlyList<WorksiteRow>> GetWorksitesAsync(
        CancellationToken cancellationToken = default)
    {
        const string select = "id,cliente_id,nome,indirizzo,gps_latitudine," +
            "gps_longitudine,raggio_presenza_metri,attivo,note," +
            "cliente:clienti!cantieri_cliente_id_fkey(ragione_sociale)";
        var payload = await SendAsync(HttpMethod.Get,
            RestUri("cantieri") + $"?select={Uri.EscapeDataString(select)}&order=nome",
            null, cancellationToken);
        return JsonSerializer.Deserialize<List<WorksiteRow>>(payload, _json) ?? [];
    }

    public async Task SaveWorksiteAsync(
        WorksiteRow? original,
        string clientId,
        string name,
        string address,
        decimal latitude,
        decimal longitude,
        int radiusMeters,
        bool active,
        string? notes,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        var body = new Dictionary<string, object?>
        {
            ["cliente_id"] = clientId,
            ["nome"] = name.Trim(),
            ["indirizzo"] = address.Trim(),
            ["gps_latitudine"] = latitude,
            ["gps_longitudine"] = longitude,
            ["raggio_presenza_metri"] = radiusMeters,
            ["attivo"] = active,
            ["note"] = EmptyToNull(notes),
            ["motivo_modifica"] = reason.Trim()
        };
        var method = original is null ? HttpMethod.Post : HttpMethod.Patch;
        var uri = RestUri("cantieri") + (original is null
            ? string.Empty
            : $"?id=eq.{Uri.EscapeDataString(original.Id)}");
        await SendAsync(method, uri, body, cancellationToken);
    }

    public async Task CreateEmployeeAsync(
        EmployeeCreateRequest employee,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["action"] = "create",
            ["nome_cognome"] = employee.FullName.Trim(),
            ["email"] = employee.Email.Trim().ToLowerInvariant(),
            ["password"] = employee.TemporaryPassword,
            ["telefono"] = EmptyToNull(employee.Phone),
            ["mansione"] = EmptyToNull(employee.Job),
            ["reparto"] = EmptyToNull(employee.Department),
            ["data_assunzione"] = employee.HireDate?.ToString("yyyy-MM-dd")
        };
        var uri = $"{_settings.SupabaseUrl.TrimEnd('/')}/functions/v1/gestione-dipendenti";
        await SendAsync(HttpMethod.Post, uri, body, cancellationToken);
    }

    public async Task<IReadOnlyList<EmployeeAccessRow>> GetEmployeeAccessAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get,
            RestUri("utenti") + "?select=id,nome_cognome,email,ruolo,attivo," +
            "dipendente_profili(telefono,mansione,reparto,data_assunzione,data_cessazione)" +
            "&order=nome_cognome",
            null, cancellationToken);
        return JsonSerializer.Deserialize<List<EmployeeAccessRow>>(payload, _json) ?? [];
    }

    public async Task SaveEmployeeAsync(
        EmployeeAccessRow employee,
        string fullName,
        string role,
        bool active,
        string? phone,
        string? job,
        string? department,
        DateTime? hireDate,
        DateTime? endDate,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        if (employee.Active != active)
            await SetEmployeeActiveAsync(employee.Id, active, cancellationToken);
        await SendAsync(HttpMethod.Patch,
            RestUri("utenti") + $"?id=eq.{Uri.EscapeDataString(employee.Id)}",
            new Dictionary<string, object?>
            {
                ["nome_cognome"] = fullName.Trim(),
                ["ruolo"] = role,
                ["attivo"] = active,
                ["motivo_modifica"] = reason.Trim()
            }, cancellationToken);
        await SendAsync(HttpMethod.Post,
            RestUri("dipendente_profili") + "?on_conflict=dipendente_id",
            new Dictionary<string, object?>
            {
                ["dipendente_id"] = employee.Id,
                ["telefono"] = EmptyToNull(phone),
                ["mansione"] = EmptyToNull(job),
                ["reparto"] = EmptyToNull(department),
                ["data_assunzione"] = hireDate?.ToString("yyyy-MM-dd"),
                ["data_cessazione"] = endDate?.ToString("yyyy-MM-dd"),
                ["motivo_modifica"] = reason.Trim()
            }, cancellationToken, upsert: true);
    }

    public async Task SetEmployeeActiveAsync(string id, bool active,
        CancellationToken cancellationToken = default) =>
        await EmployeeActionAsync(new Dictionary<string, object?>
        {
            ["action"] = "set_active", ["id"] = id, ["attivo"] = active
        }, cancellationToken);

    public async Task SetTemporaryPasswordAsync(string id, string password,
        CancellationToken cancellationToken = default) =>
        await EmployeeActionAsync(new Dictionary<string, object?>
        {
            ["action"] = "temporary_password", ["id"] = id, ["password"] = password
        }, cancellationToken);

    private async Task EmployeeActionAsync(object body, CancellationToken cancellationToken)
    {
        var uri = $"{_settings.SupabaseUrl.TrimEnd('/')}/functions/v1/gestione-dipendenti";
        await SendAsync(HttpMethod.Post, uri, body, cancellationToken);
    }

    public async Task<IReadOnlyList<AttendanceRow>> GetAttendanceAsync(
        CancellationToken cancellationToken = default)
    {
        var uri = RestUri("v_presenze_giornaliere") +
                  "?select=*&order=giorno.desc,nome_cognome.asc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<AttendanceRow>>(payload, _json) ?? [];
    }

    public async Task<IReadOnlyList<AttendanceEventRow>> GetAttendanceEventsAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get,
            RestUri("v_timbrature_amministrazione") +
            "?select=*&order=registrata_at.desc&limit=500", null, cancellationToken);
        return JsonSerializer.Deserialize<List<AttendanceEventRow>>(payload, _json) ?? [];
    }

    public async Task UpdateAttendanceTimeAsync(
        string id,
        DateTimeOffset registeredAt,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        await SendAsync(HttpMethod.Patch,
            RestUri("timbrature") + $"?id=eq.{Uri.EscapeDataString(id)}",
            new Dictionary<string, object?>
            {
                ["registrata_at"] = registeredAt.ToUniversalTime().ToString("O"),
                ["modificata_da"] = _session.UserId,
                ["motivo_modifica"] = reason.Trim()
            }, cancellationToken);
    }

    public async Task ForceAttendanceAsync(
        string employeeId,
        string type,
        DateTimeOffset registeredAt,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        await SendAsync(HttpMethod.Post, RestUri("timbrature"),
            new Dictionary<string, object?>
            {
                ["dipendente_id"] = employeeId,
                ["tipo"] = type,
                ["registrata_at"] = registeredAt.ToUniversalTime().ToString("O"),
                ["gps_latitudine"] = null,
                ["gps_longitudine"] = null,
                ["modalita"] = "sede",
                ["stato_verifica"] = "valida",
                ["forzata_da_amministratore"] = true,
                ["luogo"] = "Registrazione amministrativa",
                ["modificata_da"] = _session.UserId,
                ["motivo_modifica"] = reason.Trim()
            }, cancellationToken);
    }

    public async Task ReviewAttendanceAsync(
        string id,
        bool approved,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        await SendAsync(HttpMethod.Patch,
            RestUri("timbrature") + $"?id=eq.{Uri.EscapeDataString(id)}",
            new Dictionary<string, object?>
            {
                ["stato_verifica"] = approved ? "valida" : "rifiutata",
                ["autorizzata_da"] = _session.UserId,
                ["autorizzata_at"] = DateTimeOffset.UtcNow.ToString("O"),
                ["modificata_da"] = _session.UserId,
                ["motivo_modifica"] = reason.Trim()
            }, cancellationToken);
    }

    public async Task AuthorizeHoursAsync(
        AttendanceRow row,
        string status,
        decimal? authorizedHours,
        string reason,
        CancellationToken cancellationToken = default)
    {
        RequireReason(reason);
        await SendAsync(HttpMethod.Post,
            RestUri("presenze_revisioni") + "?on_conflict=dipendente_id,giorno",
            new Dictionary<string, object?>
            {
                ["dipendente_id"] = row.EmployeeId,
                ["giorno"] = row.Day.ToString("yyyy-MM-dd"),
                ["stato"] = status,
                ["ore_autorizzate"] = authorizedHours,
                ["nota_amministratore"] = reason.Trim(),
                ["motivo_modifica"] = reason.Trim(),
                ["autorizzata_da"] = _session.UserId,
                ["autorizzata_at"] = DateTimeOffset.UtcNow.ToString("O")
            }, cancellationToken, upsert: true);
    }

    public async Task<IReadOnlyList<DeadlineRow>> GetDeadlinesAsync(
        CancellationToken cancellationToken = default)
    {
        var uri = RestUri("v_scadenziario") +
                  "?select=*&order=data_scadenza.asc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<DeadlineRow>>(payload, _json) ?? [];
    }

    public async Task<IReadOnlyList<EmployeeDocumentRow>> GetEmployeeDocumentsAsync(
        CancellationToken cancellationToken = default)
    {
        const string select = "id,dipendente_id,categoria,titolo,ente_rilascio," +
            "numero_documento,data_rilascio,data_scadenza,esito_idoneita," +
            "documento_url,visibile_dipendente," +
            "dipendente:utenti!dipendente_documenti_dipendente_id_fkey(nome_cognome)";
        var uri = RestUri("dipendente_documenti") +
                  $"?select={Uri.EscapeDataString(select)}&attivo=eq.true&order=data_scadenza.asc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<EmployeeDocumentRow>>(payload, _json) ?? [];
    }

    public async Task AddEmployeeDocumentAsync(
        string employeeId,
        string category,
        string title,
        string? issuer,
        string? number,
        DateTime? issueDate,
        DateTime? expiryDate,
        string? fitness,
        string? documentUrl,
        bool visibleToEmployee,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["dipendente_id"] = employeeId,
            ["categoria"] = category,
            ["titolo"] = title.Trim(),
            ["ente_rilascio"] = EmptyToNull(issuer),
            ["numero_documento"] = EmptyToNull(number),
            ["data_rilascio"] = issueDate?.ToString("yyyy-MM-dd"),
            ["data_scadenza"] = expiryDate?.ToString("yyyy-MM-dd"),
            ["esito_idoneita"] = EmptyToNull(fitness),
            ["documento_url"] = EmptyToNull(documentUrl),
            ["visibile_dipendente"] = visibleToEmployee,
            ["attivo"] = true
        };
        await SendAsync(HttpMethod.Post, RestUri("dipendente_documenti"), body, cancellationToken);
    }

    public async Task SendCommunicationAsync(
        string title,
        string message,
        string priority,
        bool requireConfirmation,
        IReadOnlyCollection<string> recipientIds,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["creata_da"] = _session.UserId,
            ["titolo"] = title.Trim(),
            ["messaggio"] = message.Trim(),
            ["priorita"] = priority,
            ["richiede_conferma"] = requireConfirmation
        };
        var payload = await SendAsync(
            HttpMethod.Post,
            RestUri("comunicazioni") + "?select=id",
            body,
            cancellationToken,
            true);
        var created = JsonSerializer.Deserialize<List<CreatedId>>(payload, _json) ?? [];
        var communicationId = created.SingleOrDefault()?.Id ??
            throw new ApiException("Comunicazione non creata.");
        var recipients = recipientIds.Select(id => new Dictionary<string, object?>
        {
            ["comunicazione_id"] = communicationId,
            ["dipendente_id"] = id
        }).ToList();
        await SendAsync(
            HttpMethod.Post,
            RestUri("comunicazione_destinatari"),
            recipients,
            cancellationToken);
    }

    public async Task<IReadOnlyList<VehicleRow>> GetVehiclesAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("mezzi") + "?select=*&order=descrizione.asc",
            null,
            cancellationToken);
        return JsonSerializer.Deserialize<List<VehicleRow>>(payload, _json) ?? [];
    }

    public async Task AddVehicleAsync(
        string plate,
        string description,
        string? brand,
        string? model,
        int? km,
        CancellationToken cancellationToken = default)
    {
        await SendAsync(HttpMethod.Post, RestUri("mezzi"), new Dictionary<string, object?>
        {
            ["targa"] = plate.Trim().ToUpperInvariant(),
            ["descrizione"] = description.Trim(),
            ["marca"] = EmptyToNull(brand),
            ["modello"] = EmptyToNull(model),
            ["km_attuali"] = km,
            ["attivo"] = true
        }, cancellationToken);
    }

    public async Task<IReadOnlyList<VehicleDeadlineRow>> GetVehicleDeadlinesAsync(
        CancellationToken cancellationToken = default)
    {
        const string select = "id,mezzo_id,tipo,descrizione,fornitore_ente," +
            "numero_documento,data_scadenza,completata," +
            "mezzo:mezzi!scadenze_mezzi_mezzo_id_fkey(targa,descrizione)";
        var uri = RestUri("scadenze_mezzi") +
                  $"?select={Uri.EscapeDataString(select)}&order=data_scadenza.asc";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        return JsonSerializer.Deserialize<List<VehicleDeadlineRow>>(payload, _json) ?? [];
    }

    public async Task AddVehicleDeadlineAsync(
        string vehicleId,
        string type,
        string description,
        string? provider,
        string? documentNumber,
        DateTime expiryDate,
        CancellationToken cancellationToken = default)
    {
        await SendAsync(HttpMethod.Post, RestUri("scadenze_mezzi"), new Dictionary<string, object?>
        {
            ["mezzo_id"] = vehicleId,
            ["tipo"] = type,
            ["descrizione"] = description.Trim(),
            ["fornitore_ente"] = EmptyToNull(provider),
            ["numero_documento"] = EmptyToNull(documentNumber),
            ["data_scadenza"] = expiryDate.ToString("yyyy-MM-dd")
        }, cancellationToken);
    }

    public async Task<IReadOnlyList<CompanyCertificationRow>> GetCompanyCertificationsAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get,
            RestUri("certificazioni_azienda") + "?select=*&order=data_scadenza.asc",
            null, cancellationToken);
        return JsonSerializer.Deserialize<List<CompanyCertificationRow>>(payload, _json) ?? [];
    }

    public async Task<CompanySettingsRow> GetCompanySettingsAsync(CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get, RestUri("configurazione_azienda") + "?select=*&limit=1", null, cancellationToken);
        return (JsonSerializer.Deserialize<List<CompanySettingsRow>>(payload, _json) ?? []).FirstOrDefault()
            ?? new CompanySettingsRow { CompanyName = "Arte In Ferro Lascari" };
    }

    public async Task SaveCompanySettingsAsync(CompanySettingsRow company, CancellationToken cancellationToken = default)
    {
        RequireReason(company.ModificationReason ?? string.Empty);
        await SendAsync(HttpMethod.Patch, RestUri("configurazione_azienda") + "?id=eq.true", new Dictionary<string, object?>
        {
            ["ragione_sociale"] = company.CompanyName.Trim(), ["partita_iva"] = EmptyToNull(company.VatNumber),
            ["codice_fiscale"] = EmptyToNull(company.FiscalCode), ["indirizzo"] = EmptyToNull(company.Address),
            ["comune"] = EmptyToNull(company.City), ["provincia"] = EmptyToNull(company.Province), ["cap"] = EmptyToNull(company.PostalCode),
            ["email"] = EmptyToNull(company.Email), ["pec"] = EmptyToNull(company.Pec),
            ["telefono_principale"] = EmptyToNull(company.Phone), ["sito_web"] = EmptyToNull(company.Website),
            ["gps_latitudine"] = company.Latitude, ["gps_longitudine"] = company.Longitude,
            ["raggio_presenza_metri"] = company.AttendanceRadiusMeters,
            ["controllo_gps_presenze"] = company.AttendanceGpsEnabled,
            ["motivo_modifica"] = company.ModificationReason!.Trim()
        }, cancellationToken);
    }

    public async Task<IReadOnlyList<CompanyContactRow>> GetCompanyContactsAsync(CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(HttpMethod.Get, RestUri("contatti_azienda") + "?select=*&attivo=eq.true&order=ordine", null, cancellationToken);
        return JsonSerializer.Deserialize<List<CompanyContactRow>>(payload, _json) ?? [];
    }

    public async Task AddCompanyContactAsync(string name, string role, string? phone, string? email,
        string type, bool visible, CancellationToken cancellationToken = default)
    {
        await SendAsync(HttpMethod.Post, RestUri("contatti_azienda"), new Dictionary<string, object?>
        {
            ["nome"] = name.Trim(), ["ruolo_reparto"] = role.Trim(), ["telefono"] = EmptyToNull(phone),
            ["email"] = EmptyToNull(email), ["tipo"] = type, ["visibile_operatori"] = visible, ["attivo"] = true
        }, cancellationToken);
    }

    public async Task<IReadOnlyList<FuelRow>> GetFuelEntriesAsync(CancellationToken cancellationToken = default)
    {
        const string select = "id,data_ora,km,litri,importo,distributore,dipendente:utenti!rifornimenti_dipendente_id_fkey(nome_cognome),mezzo:mezzi!rifornimenti_mezzo_id_fkey(targa,descrizione)";
        var payload = await SendAsync(HttpMethod.Get, RestUri("rifornimenti") + $"?select={Uri.EscapeDataString(select)}&order=data_ora.desc", null, cancellationToken);
        return JsonSerializer.Deserialize<List<FuelRow>>(payload, _json) ?? [];
    }

    public async Task<IReadOnlyList<AnomalyRow>> GetAnomaliesAsync(CancellationToken cancellationToken = default)
    {
        const string select = "id,tipo,stato,titolo,descrizione,luogo,created_at,dipendente:utenti!anomalie_segnalata_da_fkey(nome_cognome),mezzo:mezzi!anomalie_mezzo_id_fkey(targa,descrizione)";
        var payload = await SendAsync(HttpMethod.Get, RestUri("anomalie") + $"?select={Uri.EscapeDataString(select)}&order=created_at.desc", null, cancellationToken);
        return JsonSerializer.Deserialize<List<AnomalyRow>>(payload, _json) ?? [];
    }

    public async Task ResolveAnomalyAsync(string id, string note, CancellationToken cancellationToken = default)
    {
        await SendAsync(HttpMethod.Patch, RestUri("anomalie") + $"?id=eq.{Uri.EscapeDataString(id)}", new Dictionary<string, object?>
        { ["stato"] = "risolta", ["nota_risoluzione"] = note.Trim(), ["risolta_da"] = _session.UserId, ["risolta_at"] = DateTime.UtcNow.ToString("O") }, cancellationToken);
    }

    public async Task AddCompanyCertificationAsync(string type, string title,
        string? issuer, string? certificateNumber, DateTime? issueDate,
        DateTime? expiryDate, string? documentUrl,
        CancellationToken cancellationToken = default)
    {
        await SendAsync(HttpMethod.Post, RestUri("certificazioni_azienda"),
            new Dictionary<string, object?>
            {
                ["categoria"] = type,
                ["titolo"] = title.Trim(),
                ["ente_rilascio"] = EmptyToNull(issuer),
                ["numero_certificato"] = EmptyToNull(certificateNumber),
                ["data_rilascio"] = issueDate?.ToString("yyyy-MM-dd"),
                ["data_scadenza"] = expiryDate?.ToString("yyyy-MM-dd"),
                ["documento_url"] = EmptyToNull(documentUrl),
                ["attiva"] = true
            }, cancellationToken);
    }

    public async Task<IReadOnlyList<LookupItem>> GetVehicleLookupAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("mezzi") + "?select=id,targa,descrizione&attivo=eq.true&order=targa",
            null,
            cancellationToken);
        var rows = JsonSerializer.Deserialize<List<VehicleLookup>>(payload, _json) ?? [];
        return rows.Select(row => new LookupItem(
            row.Id,
            string.IsNullOrWhiteSpace(row.Description)
                ? row.Plate
                : $"{row.Plate} · {row.Description}"))
            .ToList();
    }

    public async Task<IReadOnlyList<PlanningWorksiteItem>> GetPlanningWorksitesAsync(
        CancellationToken cancellationToken = default)
    {
        var payload = await SendAsync(
            HttpMethod.Get,
            RestUri("cantieri") +
            "?select=id,cliente_id,nome,indirizzo&attivo=eq.true&order=nome",
            null,
            cancellationToken);
        return JsonSerializer.Deserialize<List<PlanningWorksiteItem>>(payload, _json) ?? [];
    }

    public async Task CreateAdministrativeReportAsync(
        AdministrativeReportRequest request,
        CancellationToken cancellationToken = default)
    {
        var body = new Dictionary<string, object?>
        {
            ["dipendente_id"] = request.EmployeeId,
            ["cliente_id"] = request.ClientId,
            ["mezzo_id"] = request.VehicleId,
            ["targa_mezzo"] = EmptyToNull(request.VehiclePlate),
            ["luogo"] = request.Place.Trim(),
            ["rif_appuntamento"] = EmptyToNull(request.AppointmentReference),
            ["tipologia_intervento"] = request.InterventionType,
            ["data_ora_inizio"] = request.StartAt.ToUniversalTime().ToString("O"),
            ["data_ora_fine"] = request.EndAt.ToUniversalTime().ToString("O"),
            ["descrizione"] = request.Description.Trim(),
            ["stato"] = "bozza",
            ["pianificato"] = request.IsPlanned,
            ["pianificato_da"] = request.IsPlanned ? _session.UserId : null,
            ["pianificato_at"] = request.IsPlanned ? DateTimeOffset.UtcNow.ToString("O") : null,
            ["note_pianificazione"] = EmptyToNull(request.PlanningNotes),
            ["esito_lavoro"] = "da_eseguire",
            ["motivo_modifica"] = request.IsPlanned
                ? "Pianificazione creata dal gestionale Windows"
                : "Rapportino creato dal gestionale Windows"
        };

        var payload = await SendAsync(
            HttpMethod.Post,
            RestUri("rapportini") + "?select=id",
            body,
            cancellationToken,
            returnRepresentation: true);
        var created = JsonSerializer.Deserialize<List<CreatedId>>(payload, _json) ?? [];
        var reportId = created.SingleOrDefault()?.Id
            ?? throw new ApiException("Il rapportino non è stato creato.");

        var collaborators = request.CollaboratorIds
            .Where(id => !string.IsNullOrWhiteSpace(id) && id != request.EmployeeId)
            .Distinct()
            .Select(id => new Dictionary<string, object?>
            {
                ["rapportino_id"] = reportId,
                ["dipendente_id"] = id
            })
            .ToList();

        if (collaborators.Count > 0)
        {
            await SendAsync(
                HttpMethod.Post,
                RestUri("rapportino_collaboratori") +
                "?on_conflict=rapportino_id,dipendente_id",
                collaborators,
                cancellationToken,
                upsert: true);
        }
    }

    public async Task<ReportRow> UpdateReportAsync(
        ReportRow original,
        ReportUpdate update,
        CancellationToken cancellationToken = default)
    {
        RequireReason(update.AdminNote ?? string.Empty);
        var body = new Dictionary<string, object?>
        {
            ["luogo"] = update.Place.Trim(),
            ["rif_appuntamento"] = EmptyToNull(update.AppointmentReference),
            ["tipologia_intervento"] = update.InterventionType,
            ["data_ora_inizio"] = update.StartAt.ToUniversalTime().ToString("O"),
            ["data_ora_fine"] = update.EndAt.ToUniversalTime().ToString("O"),
            ["descrizione"] = update.Description.Trim(),
            ["stato"] = update.Status,
            ["nota_amministratore"] = EmptyToNull(update.AdminNote),
            ["motivo_modifica"] = update.AdminNote!.Trim()
        };
        var uri = RestUri("rapportini") +
                  $"?id=eq.{Uri.EscapeDataString(original.Id)}" +
                  $"&versione=eq.{original.Version}&select=*";
        var payload = await SendAsync(HttpMethod.Patch, uri, body, cancellationToken, true);
        var rows = JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
        return rows.SingleOrDefault() ?? throw new ConcurrencyException();
    }

    public async Task<ReportRow> SetStatusAsync(
        ReportRow original,
        string status,
        string? note,
        CancellationToken cancellationToken = default)
    {
        RequireReason(note ?? string.Empty);
        var body = new Dictionary<string, object?>
        {
            ["stato"] = status,
            ["nota_amministratore"] = EmptyToNull(note),
            ["motivo_modifica"] = note!.Trim()
        };
        var uri = RestUri("rapportini") +
                  $"?id=eq.{Uri.EscapeDataString(original.Id)}" +
                  $"&versione=eq.{original.Version}&select=*";
        var payload = await SendAsync(HttpMethod.Patch, uri, body, cancellationToken, true);
        var rows = JsonSerializer.Deserialize<List<ReportRow>>(payload, _json) ?? [];
        return rows.SingleOrDefault() ?? throw new ConcurrencyException();
    }

    public async Task<ReportMedia> GetMediaAsync(
        ReportRow report,
        CancellationToken cancellationToken = default)
    {
        byte[]? signature = null;
        if (!string.IsNullOrWhiteSpace(report.SignaturePath))
            signature = await DownloadPrivateFileAsync(
                "rapportini-firme",
                report.SignaturePath,
                cancellationToken);

        var uri = RestUri("rapportino_foto") +
                  $"?rapportino_id=eq.{Uri.EscapeDataString(report.Id)}" +
                  "&select=foto_url&order=created_at";
        var payload = await SendAsync(HttpMethod.Get, uri, null, cancellationToken);
        var paths = JsonSerializer.Deserialize<List<PhotoPath>>(payload, _json) ?? [];
        var photos = new List<byte[]>();
        foreach (var item in paths.Take(6))
        {
            try
            {
                photos.Add(await DownloadPrivateFileAsync(
                    "rapportini-foto",
                    item.Path,
                    cancellationToken));
            }
            catch (ApiException)
            {
                // Un singolo allegato mancante non impedisce il PDF.
            }
        }
        return new ReportMedia(signature, photos);
    }

    private async Task<byte[]> DownloadPrivateFileAsync(
        string bucket,
        string path,
        CancellationToken cancellationToken)
    {
        var signUri = $"{_settings.SupabaseUrl.TrimEnd('/')}/storage/v1/object/sign/" +
                      $"{bucket}/{EscapePath(path)}";
        var payload = await SendAsync(
            HttpMethod.Post,
            signUri,
            new { expiresIn = 300 },
            cancellationToken);
        var signed = JsonSerializer.Deserialize<SignedUrlResponse>(payload, _json);
        if (string.IsNullOrWhiteSpace(signed?.SignedUrl))
            throw new ApiException("URL temporaneo dell’allegato non disponibile.");
        var url = signed.SignedUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase)
            ? signed.SignedUrl
            : $"{_settings.SupabaseUrl.TrimEnd('/')}/storage/v1" +
              (signed.SignedUrl.StartsWith('/') ? signed.SignedUrl : "/" + signed.SignedUrl);
        using var response = await _http.GetAsync(url, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException("Impossibile scaricare un allegato privato.");
        return await response.Content.ReadAsByteArrayAsync(cancellationToken);
    }

    private async Task<string> SendAsync(
        HttpMethod method,
        string uri,
        object? body,
        CancellationToken cancellationToken,
        bool returnRepresentation = false,
        bool upsert = false)
    {
        using var request = new HttpRequestMessage(method, uri);
        request.Headers.Add("apikey", _settings.SupabasePublishableKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _session.AccessToken);
        if (returnRepresentation || upsert)
        {
            var preferences = new List<string>();
            if (upsert) preferences.Add("resolution=merge-duplicates");
            if (returnRepresentation) preferences.Add("return=representation");
            request.Headers.TryAddWithoutValidation("Prefer", string.Join(",", preferences));
        }
        if (body is not null)
        {
            request.Content = new StringContent(
                JsonSerializer.Serialize(body, _json),
                Encoding.UTF8,
                "application/json");
        }

        using var response = await _http.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new ApiException(ReadError(payload));
        return payload;
    }

    private string RestUri(string table) =>
        $"{_settings.SupabaseUrl.TrimEnd('/')}/rest/v1/{table}";

    private static string EscapePath(string path) => string.Join(
        '/',
        path.Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Select(Uri.EscapeDataString));

    private static string? EmptyToNull(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void RequireReason(string reason)
    {
        if (reason.Trim().Length < 3)
            throw new ApiException("La motivazione è obbligatoria (almeno 3 caratteri).");
    }

    private static string ReadError(string payload)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);
            var root = document.RootElement;
            foreach (var name in new[] { "message", "msg", "hint", "details" })
            {
                if (root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String)
                    return value.GetString() ?? "Errore di comunicazione con Supabase.";
            }
        }
        catch (JsonException) { }
        return "Errore di comunicazione con Supabase.";
    }


    private sealed class VehicleLookup
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("targa")]
        public string Plate { get; set; } = string.Empty;

        [JsonPropertyName("descrizione")]
        public string Description { get; set; } = string.Empty;
    }

    private sealed class UserLookup
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("nome_cognome")]
        public string Name { get; set; } = string.Empty;
    }

    private sealed class ClientLookup
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("ragione_sociale")]
        public string Name { get; set; } = string.Empty;
    }

    private sealed class PhotoPath
    {
        [JsonPropertyName("foto_url")]
        public string Path { get; set; } = string.Empty;
    }

    private sealed class SignedUrlResponse
    {
        [JsonPropertyName("signedURL")]
        public string SignedUrl { get; set; } = string.Empty;
    }

    private sealed class CreatedId
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;
    }
}
