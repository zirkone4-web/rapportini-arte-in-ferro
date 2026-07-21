import 'package:arte_in_ferro_rapportini/features/admin/data/admin_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AdminService _service = AdminService(Supabase.instance.client);
  List<Map<String, dynamic>> _daily = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _worksites = [];
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _company;
  bool _loading = true;
  bool _showEmployees = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _service.loadDailyAttendance(),
        _service.loadAttendanceEvents(),
        _service.loadEmployees(),
        _service.loadClients(),
        _service.loadWorksites(),
        _service.loadReports(),
        _service.loadCompanySettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _daily = List<Map<String, dynamic>>.from(values[0] as List);
        _events = List<Map<String, dynamic>>.from(values[1] as List);
        _employees = List<Map<String, dynamic>>.from(values[2] as List);
        _clients = List<Map<String, dynamic>>.from(values[3] as List);
        _worksites = List<Map<String, dynamic>>.from(values[4] as List);
        _reports = List<Map<String, dynamic>>.from(values[5] as List);
        _company = values[6] as Map<String, dynamic>?;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Amministrazione'),
          actions: [
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.schedule), text: 'Ore'),
              Tab(icon: Icon(Icons.fingerprint), text: 'Timbrature'),
              Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'Rapportini'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Anagrafiche'),
              Tab(icon: Icon(Icons.location_city_outlined), text: 'Cantieri'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _dailyAttendanceTab(),
                  _eventsTab(),
                  _reportsTab(),
                  _masterDataTab(),
                  _worksitesTab(),
                ],
              ),
      ),
    );
  }

  Widget _dailyAttendanceTab() {
    if (_daily.isEmpty) return const _EmptyState('Nessuna presenza registrata.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _daily.length,
        itemBuilder: (context, index) {
          final row = _daily[index];
          final day = DateTime.tryParse('${row['giorno']}');
          final entry = DateTime.tryParse('${row['prima_entrata'] ?? ''}');
          final exit = DateTime.tryParse('${row['ultima_uscita'] ?? ''}');
          final hours = (row['ore_totali'] as num?)?.toDouble();
          final authorized = (row['ore_autorizzate'] as num?)?.toDouble();
          final state = '${row['stato_ore'] ?? 'da_autorizzare'}';
          final pendingTransfer = row['contiene_trasferta_da_verificare'] == true;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${row['nome_cognome']}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      _StatusChip(state),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${day == null ? row['giorno'] : DateFormat('dd/MM/yyyy').format(day)} · '
                    'Entrata ${_time(entry)} · Uscita ${_time(exit)}',
                  ),
                  Text(
                    'Ore calcolate: ${hours?.toStringAsFixed(2) ?? '—'}'
                    '${authorized == null ? '' : ' · Autorizzate: ${authorized.toStringAsFixed(2)}'}',
                  ),
                  if (pendingTransfer)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Contiene una trasferta da verificare',
                        style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _authorizeHours(row),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('AUTORIZZA ORE'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _forceAttendance(row, 'entrata'),
                        icon: const Icon(Icons.login),
                        label: const Text('FORZA ENTRATA'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _forceAttendance(row, 'uscita'),
                        icon: const Icon(Icons.logout),
                        label: const Text('FORZA USCITA'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _eventsTab() {
    if (_events.isEmpty) return const _EmptyState('Nessuna timbratura registrata.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final row = _events[index];
          final at = DateTime.tryParse('${row['registrata_at']}');
          final latitude = (row['gps_latitudine'] as num?)?.toDouble();
          final longitude = (row['gps_longitudine'] as num?)?.toDouble();
          final pending = row['stato_verifica'] == 'da_verificare';
          return Card(
            child: ListTile(
              isThreeLine: true,
              leading: CircleAvatar(
                child: Icon(row['tipo'] == 'entrata' ? Icons.login : Icons.logout),
              ),
              title: Text('${row['nome_cognome']} · ${_label(row['tipo'])}'),
              subtitle: Text(
                '${at == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(at.toLocal())}\n'
                '${_label(row['modalita'])} · ${row['cantiere_nome'] ?? row['luogo'] ?? 'Posizione non indicata'} '
                '· ${_label(row['stato_verifica'])}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _editAttendance(row);
                  if (action == 'map' && latitude != null && longitude != null) {
                    _openMap(latitude, longitude);
                  }
                  if (action == 'approve') _reviewAttendance(row, true);
                  if (action == 'reject') _reviewAttendance(row, false);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifica data e ora')),
                  if (latitude != null && longitude != null)
                    const PopupMenuItem(value: 'map', child: Text('Apri posizione')),
                  if (pending)
                    const PopupMenuItem(value: 'approve', child: Text('Autorizza trasferta')),
                  if (pending)
                    const PopupMenuItem(value: 'reject', child: Text('Rifiuta trasferta')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _reportsTab() {
    if (_reports.isEmpty) return const _EmptyState('Nessun rapportino disponibile.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final row = _reports[index];
          final start = DateTime.tryParse('${row['data_ora_inizio']}');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_nestedEmployeeName(row['dipendente'])} · ${_nestedName(row['cliente'])}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(label: Text(_label(row['stato']))),
                    ],
                  ),
                  Text('${start == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(start.toLocal())} · ${row['luogo']} · ${row['ore_totali'] ?? 0} ore'),
                  const SizedBox(height: 4),
                  Text('${row['descrizione'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (row['nota_amministratore'] != null)
                    Text('Nota: ${row['nota_amministratore']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: row['stato'] == 'inviato'
                            ? () => _reviewReport(row, 'approvato')
                            : null,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('APPROVA'),
                      ),
                      OutlinedButton.icon(
                        onPressed: row['stato'] == 'inviato'
                            ? () => _reviewReport(row, 'respinto')
                            : null,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('RESPINGI'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _masterDataTab() {
    final rows = _showEmployees ? _employees : _clients;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.badge_outlined), label: Text('Dipendenti')),
              ButtonSegment(value: false, icon: Icon(Icons.business_outlined), label: Text('Clienti')),
            ],
            selected: {_showEmployees},
            onSelectionChanged: (value) => setState(() => _showEmployees = value.first),
          ),
        ),
        if (!_showEmployees)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: FilledButton.icon(
                onPressed: () => _editClient(null),
                icon: const Icon(Icons.add),
                label: const Text('NUOVO CLIENTE'),
              ),
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState('Nessun elemento disponibile.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(_showEmployees
                            ? Icons.person_outline
                            : Icons.business_outlined),
                        title: Text(_showEmployees
                            ? '${row['nome_cognome']}'
                            : '${row['ragione_sociale']}'),
                        subtitle: Text(_showEmployees
                            ? '${row['email']} · ${_label(row['ruolo'])}'
                            : '${row['indirizzo']}'),
                        trailing: Icon(row['attivo'] == true
                            ? Icons.check_circle_outline
                            : Icons.block),
                        onTap: () => _showEmployees
                            ? _editEmployee(row)
                            : _editClient(row),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _worksitesTab() {
    return Scaffold(
      body: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _worksites.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final company = _company;
                  final enabled = company?['controllo_gps_presenze'] == true;
                  return Card(
                    color: enabled ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                    child: ListTile(
                      leading: const Icon(Icons.factory_outlined),
                      title: Text('${company?['ragione_sociale'] ?? 'Sede aziendale'}'),
                      subtitle: Text(
                        enabled
                            ? 'Controllo posizione attivo · raggio ${company?['raggio_presenza_metri'] ?? 200} m'
                            : 'Controllo posizione non ancora attivo',
                      ),
                      trailing: const Icon(Icons.edit_location_alt_outlined),
                      onTap: _editCompanyGeofence,
                    ),
                  );
                }
                final row = _worksites[index - 1];
                final latitude = (row['gps_latitudine'] as num?)?.toDouble();
                final longitude = (row['gps_longitudine'] as num?)?.toDouble();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text('${row['nome']}'),
                    subtitle: Text(
                      '${_nestedName(row['cliente'])}\n${row['indirizzo']} · raggio ${row['raggio_presenza_metri']} m',
                    ),
                    isThreeLine: true,
                    onTap: () => _editWorksite(row),
                    trailing: IconButton(
                      tooltip: 'Apri mappa',
                      onPressed: latitude == null || longitude == null
                          ? null
                          : () => _openMap(latitude, longitude),
                      icon: const Icon(Icons.map_outlined),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editWorksite(null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('CANTIERE'),
      ),
    );
  }

  Future<void> _editAttendance(Map<String, dynamic> row) async {
    final original = DateTime.tryParse('${row['registrata_at']}')?.toLocal() ?? DateTime.now();
    final corrected = await _pickDateTime(original);
    if (corrected == null || !mounted) return;
    final reason = await _askReason('Motivo della correzione');
    if (reason == null) return;
    await _run(() => _service.updateAttendanceTime(
          id: row['id'] as String,
          dateTime: corrected,
          reason: reason,
        ));
  }

  Future<void> _forceAttendance(Map<String, dynamic> row, String type) async {
    final day = DateTime.tryParse('${row['giorno']}') ?? DateTime.now();
    final initial = DateTime(day.year, day.month, day.day, TimeOfDay.now().hour, TimeOfDay.now().minute);
    final at = await _pickDateTime(initial);
    if (at == null || !mounted) return;
    final reason = await _askReason('Motivo della registrazione forzata');
    if (reason == null) return;
    await _run(() => _service.forceAttendance(
          employeeId: row['dipendente_id'] as String,
          type: type,
          dateTime: at,
          reason: reason,
        ));
  }

  Future<void> _reviewAttendance(Map<String, dynamic> row, bool approved) async {
    final reason = await _askReason(
      approved ? 'Motivo autorizzazione trasferta' : 'Motivo rifiuto trasferta',
    );
    if (reason == null) return;
    await _run(() => _service.reviewAttendance(
          id: row['id'] as String,
          approved: approved,
          reason: reason,
        ));
  }

  Future<void> _reviewReport(Map<String, dynamic> row, String status) async {
    final reason = await _askReason(
      status == 'approvato' ? 'Nota di approvazione' : 'Motivo del rifiuto',
    );
    if (reason == null) return;
    await _run(() => _service.reviewReport(
          id: row['id'] as String,
          status: status,
          reason: reason,
        ));
  }

  Future<void> _authorizeHours(Map<String, dynamic> row) async {
    final calculated = (row['ore_totali'] as num?)?.toDouble();
    final hours = TextEditingController(
      text: ((row['ore_autorizzate'] as num?)?.toDouble() ?? calculated)?.toStringAsFixed(2) ?? '',
    );
    final reason = TextEditingController(text: '${row['nota_amministratore'] ?? ''}');
    var status = '${row['stato_ore'] ?? 'autorizzata'}';
    if (status == 'da_autorizzare') status = 'autorizzata';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ore · ${row['nome_cognome']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Stato'),
                  items: const [
                    DropdownMenuItem(value: 'autorizzata', child: Text('Autorizzata')),
                    DropdownMenuItem(value: 'rifiutata', child: Text('Rifiutata')),
                    DropdownMenuItem(value: 'da_autorizzare', child: Text('Da autorizzare')),
                  ],
                  onChanged: (value) => setDialogState(() => status = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hours,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Ore autorizzate'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Motivazione *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ANNULLA')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SALVA')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final parsed = hours.text.trim().isEmpty
        ? null
        : double.tryParse(hours.text.trim().replaceAll(',', '.'));
    if (hours.text.trim().isNotEmpty && parsed == null) {
      _showError('Ore autorizzate non valide.');
      return;
    }
    final day = DateTime.tryParse('${row['giorno']}');
    if (day == null) return;
    await _run(() => _service.authorizeHours(
          employeeId: row['dipendente_id'] as String,
          day: day,
          status: status,
          authorizedHours: parsed,
          reason: reason.text,
        ));
  }

  Future<void> _editEmployee(Map<String, dynamic> row) async {
    final profileValue = row['dipendente_profili'];
    final profile = profileValue is List && profileValue.isNotEmpty
        ? Map<String, dynamic>.from(profileValue.first as Map)
        : profileValue is Map
            ? Map<String, dynamic>.from(profileValue)
            : <String, dynamic>{};
    final name = TextEditingController(text: '${row['nome_cognome'] ?? ''}');
    final phone = TextEditingController(text: '${profile['telefono'] ?? ''}');
    final job = TextEditingController(text: '${profile['mansione'] ?? ''}');
    final department = TextEditingController(text: '${profile['reparto'] ?? ''}');
    final hireDate = TextEditingController(text: '${profile['data_assunzione'] ?? ''}');
    final endDate = TextEditingController(text: '${profile['data_cessazione'] ?? ''}');
    final reason = TextEditingController();
    var role = '${row['ruolo'] ?? 'operatore'}';
    var active = row['attivo'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica dipendente'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome e cognome *')),
                  const SizedBox(height: 10),
                  TextField(enabled: false, controller: TextEditingController(text: '${row['email']}'), decoration: const InputDecoration(labelText: 'Email account')),
                  const SizedBox(height: 10),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefono')),
                  const SizedBox(height: 10),
                  TextField(controller: job, decoration: const InputDecoration(labelText: 'Mansione')),
                  const SizedBox(height: 10),
                  TextField(controller: department, decoration: const InputDecoration(labelText: 'Reparto')),
                  const SizedBox(height: 10),
                  TextField(controller: hireDate, decoration: const InputDecoration(labelText: 'Data assunzione (AAAA-MM-GG)')),
                  const SizedBox(height: 10),
                  TextField(controller: endDate, decoration: const InputDecoration(labelText: 'Data cessazione (AAAA-MM-GG)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Ruolo'),
                    items: const [
                      DropdownMenuItem(value: 'operatore', child: Text('Operatore')),
                      DropdownMenuItem(value: 'admin', child: Text('Amministratore')),
                    ],
                    onChanged: (value) => setDialogState(() => role = value!),
                  ),
                  SwitchListTile(
                    value: active,
                    title: const Text('Account attivo'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                  TextField(controller: reason, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Motivazione modifica *')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ANNULLA')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SALVA')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _run(() => _service.saveEmployee(
          id: row['id'] as String,
          fullName: name.text,
          role: role,
          active: active,
          phone: phone.text,
          job: job.text,
          department: department.text,
          hireDate: DateTime.tryParse(hireDate.text.trim()),
          endDate: DateTime.tryParse(endDate.text.trim()),
          reason: reason.text,
        ));
  }

  Future<void> _editClient(Map<String, dynamic>? row) async {
    final name = TextEditingController(text: '${row?['ragione_sociale'] ?? ''}');
    final address = TextEditingController(text: '${row?['indirizzo'] ?? ''}');
    final contact = TextEditingController(text: '${row?['referente'] ?? ''}');
    final phone = TextEditingController(text: '${row?['telefono'] ?? ''}');
    final reason = TextEditingController();
    var active = row?['attivo'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(row == null ? 'Nuovo cliente' : 'Modifica cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Ragione sociale *')),
                const SizedBox(height: 10),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Indirizzo *')),
                const SizedBox(height: 10),
                TextField(controller: contact, decoration: const InputDecoration(labelText: 'Referente')),
                const SizedBox(height: 10),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefono')),
                SwitchListTile(value: active, title: const Text('Cliente attivo'), contentPadding: EdgeInsets.zero, onChanged: (value) => setDialogState(() => active = value)),
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivazione *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ANNULLA')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SALVA')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _run(() => _service.saveClient(
          id: row?['id'] as String?,
          name: name.text,
          address: address.text,
          contact: contact.text,
          phone: phone.text,
          active: active,
          reason: reason.text,
        ));
  }

  Future<void> _editWorksite(Map<String, dynamic>? row) async {
    if (_clients.isEmpty) {
      _showError('Crea prima almeno un cliente.');
      return;
    }
    final name = TextEditingController(text: '${row?['nome'] ?? ''}');
    final address = TextEditingController(text: '${row?['indirizzo'] ?? ''}');
    final latitude = TextEditingController(text: '${row?['gps_latitudine'] ?? ''}');
    final longitude = TextEditingController(text: '${row?['gps_longitudine'] ?? ''}');
    final radius = TextEditingController(text: '${row?['raggio_presenza_metri'] ?? 200}');
    final notes = TextEditingController(text: '${row?['note'] ?? ''}');
    final reason = TextEditingController();
    var clientId = row?['cliente_id'] as String? ?? _clients.first['id'] as String;
    var active = row?['attivo'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(row == null ? 'Nuovo cantiere' : 'Modifica cantiere'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: clientId,
                    decoration: const InputDecoration(labelText: 'Cliente *'),
                    items: _clients
                        .where((item) => item['attivo'] == true || item['id'] == clientId)
                        .map((item) => DropdownMenuItem(
                              value: item['id'] as String,
                              child: Text('${item['ragione_sociale']}'),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => clientId = value!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome cantiere *')),
                  const SizedBox(height: 10),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Indirizzo *')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitudine *'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitudine *'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: radius, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Raggio autorizzato (metri) *')),
                  const SizedBox(height: 10),
                  TextField(controller: notes, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Note')),
                  SwitchListTile(value: active, title: const Text('Cantiere attivo'), contentPadding: EdgeInsets.zero, onChanged: (value) => setDialogState(() => active = value)),
                  TextField(controller: reason, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Motivazione *')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ANNULLA')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SALVA')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final lat = double.tryParse(latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(longitude.text.trim().replaceAll(',', '.'));
    final parsedRadius = int.tryParse(radius.text.trim());
    if (lat == null || lon == null || parsedRadius == null) {
      _showError('Latitudine, longitudine o raggio non validi.');
      return;
    }
    await _run(() => _service.saveWorksite(
          id: row?['id'] as String?,
          clientId: clientId,
          name: name.text,
          address: address.text,
          latitude: lat,
          longitude: lon,
          radius: parsedRadius,
          active: active,
          notes: notes.text,
          reason: reason.text,
        ));
  }

  Future<void> _editCompanyGeofence() async {
    final latitude = TextEditingController(text: '${_company?['gps_latitudine'] ?? ''}');
    final longitude = TextEditingController(text: '${_company?['gps_longitudine'] ?? ''}');
    final radius = TextEditingController(text: '${_company?['raggio_presenza_metri'] ?? 200}');
    final reason = TextEditingController();
    var enabled = _company?['controllo_gps_presenze'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Posizione sede aziendale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Inserisci le coordinate della sede. Attiva il controllo soltanto dopo averle verificate sulla mappa.'),
                const SizedBox(height: 12),
                TextField(controller: latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitudine *')),
                const SizedBox(height: 10),
                TextField(controller: longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitudine *')),
                const SizedBox(height: 10),
                TextField(controller: radius, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Raggio autorizzato (metri) *')),
                SwitchListTile(value: enabled, title: const Text('Controllo posizione attivo'), contentPadding: EdgeInsets.zero, onChanged: (value) => setDialogState(() => enabled = value)),
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'Motivazione *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ANNULLA')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SALVA')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final lat = double.tryParse(latitude.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(longitude.text.trim().replaceAll(',', '.'));
    final parsedRadius = int.tryParse(radius.text.trim());
    if (lat == null || lon == null || parsedRadius == null) {
      _showError('Coordinate o raggio non validi.');
      return;
    }
    await _run(() => _service.saveCompanyGeofence(
          latitude: lat,
          longitude: lon,
          radius: parsedRadius,
          enabled: enabled,
          reason: reason.text,
        ));
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<String?> _askReason(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Motivazione obbligatoria'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ANNULLA')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('CONFERMA')),
        ],
      ),
    );
    return value?.trim().isEmpty == true ? null : value;
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Impossibile aprire la mappa.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      setState(() => _loading = true);
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifica salvata e registrata nello storico.')),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _loading = false);
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('PostgrestException(message: ', '')
        .split(', code:')
        .first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _time(DateTime? value) =>
      value == null ? '—' : DateFormat('HH:mm').format(value.toLocal());

  String _label(Object? value) => switch ('$value') {
        'entrata' => 'Entrata',
        'uscita' => 'Uscita',
        'sede' => 'Sede',
        'cantiere' => 'Cantiere',
        'trasferta' => 'Trasferta',
        'valida' => 'Valida',
        'da_verificare' => 'Da verificare',
        'rifiutata' => 'Rifiutata',
        'da_autorizzare' => 'Da autorizzare',
        'autorizzata' => 'Autorizzata',
        'admin' => 'Amministratore',
        'operatore' => 'Operatore',
        'bozza' => 'Bozza',
        'inviato' => 'Inviato',
        'approvato' => 'Approvato',
        'respinto' => 'Respinto',
        final text => text,
      };

  String _nestedName(Object? value) {
    if (value is Map) return '${value['ragione_sociale'] ?? 'Cliente'}';
    if (value is List && value.isNotEmpty && value.first is Map) {
      return '${(value.first as Map)['ragione_sociale'] ?? 'Cliente'}';
    }
    return 'Cliente';
  }

  String _nestedEmployeeName(Object? value) {
    if (value is Map) return '${value['nome_cognome'] ?? 'Dipendente'}';
    if (value is List && value.isNotEmpty && value.first is Map) {
      return '${(value.first as Map)['nome_cognome'] ?? 'Dipendente'}';
    }
    return 'Dipendente';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'autorizzata' => ('Autorizzata', Colors.green),
      'rifiutata' => ('Rifiutata', Colors.red),
      _ => ('Da autorizzare', Colors.orange),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      backgroundColor: color.withValues(alpha: 0.10),
    );
  }
}
