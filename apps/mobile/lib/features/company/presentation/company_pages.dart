import 'package:arte_in_ferro_rapportini/core/gps/location_service.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/company/data/company_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

CompanyService _service() => CompanyService(Supabase.instance.client);

class AttendancePage extends StatefulWidget {
  const AttendancePage({required this.user, super.key});

  final AppUser user;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Map<String, dynamic>? _latest;
  List<Map<String, dynamic>> _vehicles = [];
  String? _vehicleId;
  bool _loading = true;
  bool _saving = false;

  bool get _isInside => _latest?['tipo'] == 'entrata';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _service().latestAttendance(widget.user.id),
        _service().loadVehicles(),
      ]);
      if (!mounted) return;
      setState(() {
        _latest = values[0] as Map<String, dynamic>?;
        _vehicles = values[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  Future<void> _register() async {
    setState(() => _saving = true);
    try {
      final location = await LocationService().capture();
      await _service().registerAttendance(
        employeeId: widget.user.id,
        type: _isInside ? 'uscita' : 'entrata',
        location: location,
        vehicleId: _vehicleId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInside ? 'Entrata registrata' : 'Uscita registrata'),
          ),
        );
      }
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Operazione non riuscita: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestAt = DateTime.tryParse('${_latest?['registrata_at'] ?? ''}');
    return Scaffold(
      appBar: AppBar(title: const Text('Presenze')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _StatusCard(
                  active: _isInside,
                  title: _isInside ? 'Sei presente' : 'Non sei in servizio',
                  subtitle: latestAt == null
                      ? 'Nessuna timbratura registrata oggi'
                      : 'Ultima registrazione: '
                          '${DateFormat('HH:mm').format(latestAt.toLocal())}',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String?>(
                  initialValue: _vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Mezzo utilizzato (facoltativo)',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nessun mezzo')),
                    ..._vehicles.map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle['id'] as String,
                        child: Text('${vehicle['targa']} · ${vehicle['descrizione']}'),
                      ),
                    ),
                  ],
                  onChanged: _saving ? null : (value) => setState(() => _vehicleId = value),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _register,
                  icon: Icon(_isInside ? Icons.logout : Icons.login),
                  label: Text(
                    _saving
                        ? 'REGISTRAZIONE…'
                        : _isInside
                            ? 'REGISTRA USCITA'
                            : 'REGISTRA ENTRATA',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La posizione viene acquisita esclusivamente quando premi il '
                  'pulsante. Non viene effettuato alcun tracciamento continuo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class FuelPage extends StatefulWidget {
  const FuelPage({required this.user, super.key});

  final AppUser user;

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  final _key = GlobalKey<FormState>();
  final _km = TextEditingController();
  final _liters = TextEditingController();
  final _amount = TextEditingController();
  final _station = TextEditingController();
  List<Map<String, dynamic>> _vehicles = [];
  String? _vehicleId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service().loadVehicles().then((value) {
      if (mounted) setState(() => _vehicles = value);
    });
  }

  @override
  void dispose() {
    _km.dispose();
    _liters.dispose();
    _amount.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      LocationSnapshot? location;
      try {
        location = await LocationService().capture();
      } on Object {
        location = null;
      }
      await _service().registerFuel(
        employeeId: widget.user.id,
        vehicleId: _vehicleId!,
        km: int.parse(_km.text.trim()),
        liters: double.parse(_liters.text.trim().replaceAll(',', '.')),
        amount: _amount.text.trim().isEmpty
            ? null
            : double.parse(_amount.text.trim().replaceAll(',', '.')),
        station: _station.text,
        location: location,
      );
      if (!mounted) return;
      _key.currentState!.reset();
      _km.clear();
      _liters.clear();
      _amount.clear();
      _station.clear();
      setState(() => _vehicleId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rifornimento registrato')),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salvataggio non riuscito: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carburante')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(
                labelText: 'Mezzo *',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: _vehicles
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle['id'] as String,
                      child: Text('${vehicle['targa']} · ${vehicle['descrizione']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _vehicleId = value),
              validator: (value) => value == null ? 'Seleziona il mezzo' : null,
            ),
            const SizedBox(height: 12),
            _numberField(_km, 'Chilometri *', Icons.speed_outlined),
            const SizedBox(height: 12),
            _numberField(_liters, 'Litri *', Icons.local_gas_station_outlined),
            const SizedBox(height: 12),
            _numberField(_amount, 'Importo', Icons.euro_outlined, required: false),
            const SizedBox(height: 12),
            TextFormField(
              controller: _station,
              decoration: const InputDecoration(
                labelText: 'Distributore',
                prefixIcon: Icon(Icons.store_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'SALVATAGGIO…' : 'REGISTRA RIFORNIMENTO'),
            ),
          ],
        ),
      ),
    );
  }

  TextFormField _numberField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        if (!required && (value == null || value.trim().isEmpty)) return null;
        final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
        return parsed == null || parsed < 0 ? 'Inserisci un valore valido' : null;
      },
    );
  }
}

class AnomalyPage extends StatefulWidget {
  const AnomalyPage({required this.user, super.key});

  final AppUser user;

  @override
  State<AnomalyPage> createState() => _AnomalyPageState();
}

class _AnomalyPageState extends State<AnomalyPage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  String _type = 'sicurezza';
  String? _vehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service().loadVehicles().then((value) {
      if (mounted) setState(() => _vehicles = value);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      LocationSnapshot? location;
      try {
        location = await LocationService().capture();
      } on Object {
        location = null;
      }
      await _service().reportAnomaly(
        employeeId: widget.user.id,
        type: _type,
        title: _title.text,
        description: _description.text,
        place: _place.text,
        vehicleId: _vehicleId,
        location: location,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anomalia inviata all’ufficio')),
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invio non riuscito: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const types = {
      'sicurezza': 'Sicurezza',
      'mezzo': 'Mezzo',
      'attrezzatura': 'Attrezzatura',
      'cantiere': 'Cantiere',
      'materiale': 'Materiale',
      'qualita': 'Qualità',
      'altro': 'Altro',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Segnala anomalia')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo di anomalia *'),
              items: types.entries
                  .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titolo *'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Descrizione *'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'Luogo / cantiere'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _vehicleId,
              decoration: const InputDecoration(labelText: 'Mezzo coinvolto'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nessun mezzo')),
                ..._vehicles.map(
                  (vehicle) => DropdownMenuItem(
                    value: vehicle['id'] as String,
                    child: Text('${vehicle['targa']} · ${vehicle['descrizione']}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _vehicleId = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send_outlined),
              label: Text(_saving ? 'INVIO…' : 'INVIA SEGNALAZIONE'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().length < 3 ? 'Campo obbligatorio' : null;
}

class EmployeeDocumentsPage extends StatelessWidget {
  const EmployeeDocumentsPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I miei documenti')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service().loadEmployeeDocuments(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _Failure(message: '${snapshot.error}');
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _Empty(
              icon: Icons.badge_outlined,
              message: 'Nessun documento disponibile',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _DocumentCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class CommunicationsPage extends StatefulWidget {
  const CommunicationsPage({required this.user, super.key});

  final AppUser user;

  @override
  State<CommunicationsPage> createState() => _CommunicationsPageState();
}

class _CommunicationsPageState extends State<CommunicationsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service().loadCommunications(widget.user.id);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final message = Map<String, dynamic>.from(row['comunicazioni'] as Map);
    final confirm = message['richiede_conferma'] == true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${message['titolo']}'),
        content: SingleChildScrollView(child: Text('${message['messaggio']}')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(confirm ? 'HO LETTO E CONFERMO' : 'HO LETTO'),
          ),
        ],
      ),
    );
    await _service().markCommunication(
      employeeId: widget.user.id,
      communicationId: '${row['comunicazione_id']}',
      confirm: confirm,
    );
    if (mounted) {
      setState(() => _future = _service().loadCommunications(widget.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicazioni')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _Failure(message: '${snapshot.error}');
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const _Empty(
              icon: Icons.notifications_none,
              message: 'Nessuna comunicazione',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final message = Map<String, dynamic>.from(row['comunicazioni'] as Map);
              final unread = row['letta_at'] == null;
              return Card(
                child: ListTile(
                  leading: Icon(
                    unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
                  ),
                  title: Text(
                    '${message['titolo']}',
                    style: TextStyle(fontWeight: unread ? FontWeight.w800 : null),
                  ),
                  subtitle: Text(
                    '${message['messaggio']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(row),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CompanyInfoPage extends StatelessWidget {
  const CompanyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informazioni azienda')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _service().loadCompany(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _Failure(message: '${snapshot.error}');
          final item = snapshot.data;
          if (item == null) return const _Empty(icon: Icons.factory_outlined, message: 'Dati non disponibili');
          final fields = <(IconData, String, Object?)>[
            (Icons.factory_outlined, 'Ragione sociale', item['ragione_sociale']),
            (Icons.location_on_outlined, 'Indirizzo', item['indirizzo']),
            (Icons.phone_outlined, 'Telefono', item['telefono_principale']),
            (Icons.email_outlined, 'Email', item['email']),
            (Icons.language_outlined, 'Sito', item['sito_web']),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: fields
                .where((field) => '${field.$3 ?? ''}'.trim().isNotEmpty)
                .map(
                  (field) => Card(
                    child: ListTile(
                      leading: Icon(field.$1),
                      title: Text(field.$2),
                      subtitle: Text('${field.$3}'),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contatti ed emergenze')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _service().loadContacts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _Failure(message: '${snapshot.error}');
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const _Empty(icon: Icons.contact_phone_outlined, message: 'Nessun contatto disponibile');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final phone = '${item['telefono'] ?? ''}';
              return Card(
                child: ListTile(
                  leading: Icon(item['tipo'] == 'emergenza' ? Icons.sos : Icons.person_outline),
                  title: Text('${item['nome']}'),
                  subtitle: Text('${item['ruolo_reparto']}${phone.isEmpty ? '' : '\n$phone'}'),
                  isThreeLine: phone.isNotEmpty,
                  trailing: phone.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Chiama',
                          icon: const Icon(Icons.phone),
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.active, required this.title, required this.subtitle});

  final bool active;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF15803D) : const Color(0xFF475569);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(active ? Icons.check_circle : Icons.schedule, size: 58, color: color),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final expiry = DateTime.tryParse('${item['data_scadenza'] ?? ''}');
    final days = expiry?.difference(DateTime.now()).inDays;
    final color = days == null
        ? const Color(0xFF475569)
        : days < 0
            ? const Color(0xFFDC2626)
            : days <= 30
                ? const Color(0xFFCA8A04)
                : const Color(0xFF15803D);
    final url = '${item['documento_url'] ?? ''}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text('${item['titolo']}', style: const TextStyle(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 8),
            Text('Categoria: ${item['categoria']}'),
            if (expiry != null) Text('Scadenza: ${DateFormat('dd/MM/yyyy').format(expiry)}'),
            if ('${item['esito_idoneita'] ?? ''}'.isNotEmpty) Text('Idoneità: ${item['esito_idoneita']}'),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('VISUALIZZA DOCUMENTO'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 58), const SizedBox(height: 12), Text(message)],
        ),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Impossibile caricare i dati.\n$message', textAlign: TextAlign.center),
        ),
      );
}
