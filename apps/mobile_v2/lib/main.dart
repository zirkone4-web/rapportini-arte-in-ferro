import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://oibibghbgcdjyimkvere.supabase.co',
);
const _supabaseKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_a2pl_IOhqK3c7_gHUBnnmw_MoKaoptI',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const ArteInFerroApp());
}

class ArteInFerroApp extends StatefulWidget {
  const ArteInFerroApp({super.key});

  @override
  State<ArteInFerroApp> createState() => _ArteInFerroAppState();
}

class _ArteInFerroAppState extends State<ArteInFerroApp> {
  StreamSubscription<AuthState>? _subscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _session = auth.currentSession;
    _subscription = auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() => _session = event.session);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF12385B));
    return MaterialApp(
      title: 'Arte In Ferro Lascari',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colors,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F6F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF17212B),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: _session == null ? const LoginPage() : const HomePage(),
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: '${map['id']}',
        name: '${map['nome_cognome'] ?? ''}',
        email: '${map['email'] ?? ''}',
        role: '${map['ruolo'] ?? 'operatore'}',
        active: map['attivo'] == true,
      );

  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;
}

class Report {
  const Report({
    required this.id,
    required this.employeeId,
    required this.clientId,
    required this.clientName,
    required this.place,
    required this.type,
    required this.start,
    required this.description,
    required this.status,
    required this.version,
    required this.planned,
    this.end,
    this.reference,
    this.vehicleId,
    this.plate,
    this.km,
    this.signaturePath,
    this.adminNote,
    this.planningNote,
    this.outcome = 'da_eseguire',
    this.incompleteNote,
  });

  factory Report.fromMap(Map<String, dynamic> map) {
    final clientRaw = map['cliente'];
    final client = clientRaw is Map
        ? Map<String, dynamic>.from(clientRaw)
        : const <String, dynamic>{};
    return Report(
      id: '${map['id']}',
      employeeId: '${map['dipendente_id']}',
      clientId: '${map['cliente_id']}',
      clientName: '${client['ragione_sociale'] ?? 'Cliente'}',
      place: '${map['luogo'] ?? ''}',
      type: '${map['tipologia_intervento'] ?? 'altro'}',
      start: DateTime.parse('${map['data_ora_inizio']}'),
      end: map['data_ora_fine'] == null
          ? null
          : DateTime.parse('${map['data_ora_fine']}'),
      description: '${map['descrizione'] ?? ''}',
      status: '${map['stato'] ?? 'bozza'}',
      version: (map['versione'] as num?)?.toInt() ?? 1,
      planned: map['pianificato'] == true,
      reference: map['rif_appuntamento'] as String?,
      vehicleId: map['mezzo_id'] as String?,
      plate: map['targa_mezzo'] as String?,
      km: (map['km_mezzo'] as num?)?.toInt(),
      signaturePath: map['firma_cliente_url'] as String?,
      adminNote: map['nota_amministratore'] as String?,
      planningNote: map['note_pianificazione'] as String?,
      outcome: '${map['esito_lavoro'] ?? 'da_eseguire'}',
      incompleteNote: map['nota_lavoro_incompleto'] as String?,
    );
  }

  final String id;
  final String employeeId;
  final String clientId;
  final String clientName;
  final String place;
  final String type;
  final DateTime start;
  final DateTime? end;
  final String description;
  final String status;
  final int version;
  final bool planned;
  final String? reference;
  final String? vehicleId;
  final String? plate;
  final int? km;
  final String? signaturePath;
  final String? adminNote;
  final String? planningNote;
  final String outcome;
  final String? incompleteNote;

  bool get editable => status == 'bozza' || status == 'respinto';
}

class Communication {
  const Communication({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.requiresConfirmation,
    required this.published,
    required this.read,
    required this.confirmed,
  });

  factory Communication.fromMap(Map<String, dynamic> recipient) {
    final raw = recipient['comunicazioni'];
    final message = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return Communication(
      id: '${message['id'] ?? recipient['comunicazione_id']}',
      title: '${message['titolo'] ?? 'Comunicazione'}',
      message: '${message['messaggio'] ?? ''}',
      priority: '${message['priorita'] ?? 'normale'}',
      requiresConfirmation: message['richiede_conferma'] == true,
      published: DateTime.tryParse('${message['pubblicata_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      read: recipient['letta_at'] != null,
      confirmed: recipient['confermata_at'] != null,
    );
  }

  final String id;
  final String title;
  final String message;
  final String priority;
  final bool requiresConfirmation;
  final DateTime published;
  final bool read;
  final bool confirmed;
}

class CloudService {
  CloudService(this.client);

  final SupabaseClient client;
  static const _uuid = Uuid();

  Future<AppUser> profile() async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sessione non disponibile.');
    final row = await client
        .from('utenti')
        .select('id,nome_cognome,email,ruolo,attivo')
        .eq('id', id)
        .single();
    final user = AppUser.fromMap(row);
    if (!user.active) {
      await client.auth.signOut();
      throw StateError('Account disattivato.');
    }
    return user;
  }

  Future<List<Report>> reports() async {
    final rows = await client
        .from('rapportini')
        .select(
          'id,dipendente_id,cliente_id,luogo,rif_appuntamento,mezzo_id,'
          'targa_mezzo,km_mezzo,tipologia_intervento,data_ora_inizio,'
          'data_ora_fine,descrizione,firma_cliente_url,stato,'
          'nota_amministratore,versione,pianificato,note_pianificazione,'
          'esito_lavoro,nota_lavoro_incompleto,'
          'cliente:clienti!rapportini_cliente_id_fkey(ragione_sociale)',
        )
        .order('data_ora_inizio', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .map(Report.fromMap)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> clients() async {
    final rows = await client
        .from('clienti')
        .select('id,ragione_sociale,indirizzo')
        .order('ragione_sociale');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> vehicles() async {
    final rows = await client
        .from('mezzi')
        .select('id,targa,descrizione,km_attuali')
        .eq('attivo', true)
        .order('descrizione');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> saveDraft({
    Report? original,
    required AppUser user,
    required String clientId,
    required String place,
    required String type,
    required DateTime start,
    DateTime? end,
    required String description,
    String? reference,
    String? vehicleId,
    String? plate,
    int? km,
    required String outcome,
    String? incompleteNote,
  }) async {
    final payload = <String, dynamic>{
      'cliente_id': clientId,
      'luogo': place.trim(),
      'rif_appuntamento': _emptyToNull(reference),
      'mezzo_id': vehicleId,
      'targa_mezzo': _emptyToNull(plate),
      'km_mezzo': km,
      'tipologia_intervento': type,
      'data_ora_inizio': start.toUtc().toIso8601String(),
      'data_ora_fine': end?.toUtc().toIso8601String(),
      'descrizione': description.trim(),
      'esito_lavoro': outcome,
      'nota_lavoro_incompleto': _emptyToNull(incompleteNote),
      'stato': 'bozza',
    };

    if (original == null) {
      return client
          .from('rapportini')
          .insert({
            'id': _uuid.v4(),
            'dipendente_id': user.id,
            ...payload,
          })
          .select()
          .single();
    }

    final rows = await client
        .from('rapportini')
        .update(payload)
        .eq('id', original.id)
        .eq('versione', original.version)
        .select();
    if (rows.isEmpty) {
      throw StateError(
        'Il rapportino è stato modificato dall’ufficio. Aggiorna e riprova.',
      );
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<String> uploadSignature(
    String userId,
    String reportId,
    Uint8List bytes,
  ) async {
    final path = '$userId/$reportId/firma_cliente.png';
    await client.storage.from('rapportini-firme').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
    return path;
  }

  Future<void> uploadPhoto(
    String userId,
    String reportId,
    Uint8List bytes,
  ) async {
    final id = _uuid.v4();
    final path = '$userId/$reportId/$id.jpg';
    await client.storage.from('rapportini-foto').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    await client.from('rapportino_foto').insert({
      'id': id,
      'rapportino_id': reportId,
      'foto_url': path,
    });
  }

  Future<void> updateSignature({
    required String reportId,
    required int version,
    required String signaturePath,
    required bool submit,
  }) async {
    final rows = await client
        .from('rapportini')
        .update({
          'firma_cliente_url': signaturePath,
          if (submit) 'stato': 'inviato',
        })
        .eq('id', reportId)
        .eq('versione', version)
        .select();
    if (rows.isEmpty) {
      throw StateError('Conflitto di salvataggio. Aggiorna e riprova.');
    }
  }

  Future<Position> position() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Autorizzazione posizione non concessa.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Attiva il GPS.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<Map<String, dynamic>?> latestAttendance(String employeeId) async {
    final rows = await client
        .from('timbrature')
        .select('id,tipo,registrata_at,luogo,modalita,stato_verifica')
        .eq('dipendente_id', employeeId)
        .order('registrata_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> attendanceConfiguration() async {
    final results = await Future.wait([
      client
          .from('configurazione_azienda')
          .select(
            'ragione_sociale,gps_latitudine,gps_longitudine,'
            'raggio_presenza_metri,controllo_gps_presenze',
          )
          .limit(1),
      client
          .from('cantieri')
          .select(
            'id,nome,gps_latitudine,gps_longitudine,raggio_presenza_metri',
          )
          .eq('attivo', true)
          .order('nome'),
      vehicles(),
    ]);

    final company = List<Map<String, dynamic>>.from(results[0] as List);
    return {
      'company': company.isEmpty ? null : company.first,
      'worksites': List<Map<String, dynamic>>.from(results[1] as List),
      'vehicles': results[2],
    };
  }

  Future<void> registerAttendance({
    required AppUser user,
    required String type,
    required Position position,
    required String mode,
    String? worksiteId,
    String? transferReason,
    String? vehicleId,
    String? place,
  }) async {
    await client.from('timbrature').insert({
      'dipendente_id': user.id,
      'tipo': type,
      'registrata_at': DateTime.now().toUtc().toIso8601String(),
      'gps_latitudine': position.latitude,
      'gps_longitudine': position.longitude,
      'gps_precisione_metri': position.accuracy,
      'modalita': mode,
      'cantiere_id': worksiteId,
      'trasferta_motivo': _emptyToNull(transferReason),
      'mezzo_id': vehicleId,
      'luogo': _emptyToNull(place),
    });
  }

  Future<List<Communication>> communications(String employeeId) async {
    final rows = await client
        .from('comunicazione_destinatari')
        .select(
          'comunicazione_id,letta_at,confermata_at,'
          'comunicazioni(id,titolo,messaggio,priorita,richiede_conferma,'
          'pubblicata_at)',
        )
        .eq('dipendente_id', employeeId)
        .order('comunicazione_id', ascending: false);
    final items = List<Map<String, dynamic>>.from(rows)
        .map(Communication.fromMap)
        .toList();
    items.sort((a, b) => b.published.compareTo(a.published));
    return items;
  }

  Future<void> markCommunication({
    required AppUser user,
    required String communicationId,
    required bool confirm,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await client
        .from('comunicazione_destinatari')
        .update({
          'letta_at': now,
          if (confirm) 'confermata_at': now,
        })
        .eq('dipendente_id', user.id)
        .eq('comunicazione_id', communicationId);
  }

  String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Accesso non riuscito. Controlla Internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 35,
                            backgroundColor: Color(0xFF12385B),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.factory_outlined, size: 38),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Arte In Ferro Lascari',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'App aziendale Android e iPhone',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) =>
                                (value?.contains('@') ?? false)
                                    ? null
                                    : 'Inserisci un’email valida.',
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            onFieldSubmitted: (_) => _busy ? null : _login(),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'Inserisci la password.'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _busy ? null : _login,
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_busy ? 'ACCESSO…' : 'ACCEDI'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CloudService _service;
  late Future<AppUser> _user;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _service = CloudService(Supabase.instance.client);
    _user = _service.profile();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppUser>(
        future: _user,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        _clean(snapshot.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _user = _service.profile()),
                        child: const Text('RIPROVA'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final user = snapshot.data!;
          final pages = [
            ReportsPage(user: user, service: _service),
            AttendancePage(user: user, service: _service),
            CommunicationsPage(user: user, service: _service),
            ProfilePage(user: user),
          ];

          return Scaffold(
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Rapportini',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fingerprint),
                  label: 'Presenze',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Avvisi',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profilo',
                ),
              ],
            ),
          );
        },
      );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    required this.user,
    required this.service,
    super.key,
  });

  final AppUser user;
  final CloudService service;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<List<Report>> _future;
  String _filter = 'tutti';

  @override
  void initState() {
    super.initState();
    _future = widget.service.reports();
  }

  Future<void> _refresh() async {
    final future = widget.service.reports();
    setState(() => _future = future);
    await future;
  }

  Future<void> _edit([Report? report]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportEditor(
          user: widget.user,
          service: widget.service,
          report: report,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Rapportini'),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('NUOVO'),
        ),
        body: FutureBuilder<List<Report>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: _clean(snapshot.error), retry: _refresh);
            }

            final all = snapshot.data ?? const [];
            final items = _filter == 'tutti'
                ? all
                : all.where((report) => report.status == _filter).toList();

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _filter,
                    decoration: const InputDecoration(
                      labelText: 'Filtra',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'tutti',
                        child: Text('Tutti'),
                      ),
                      DropdownMenuItem(
                        value: 'bozza',
                        child: Text('Bozze'),
                      ),
                      DropdownMenuItem(
                        value: 'inviato',
                        child: Text('Inviati'),
                      ),
                      DropdownMenuItem(
                        value: 'approvato',
                        child: Text('Approvati'),
                      ),
                      DropdownMenuItem(
                        value: 'respinto',
                        child: Text('Respinti'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? 'tutti'),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const EmptyView(
                      icon: Icons.description_outlined,
                      text: 'Nessun rapportino.',
                    )
                  else
                    ...items.map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReportCard(
                          report: report,
                          onTap: () => report.editable
                              ? _edit(report)
                              : _details(report),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  Future<void> _details(Report report) async {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          children: [
            Text(
              report.clientName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DetailRow('Stato', _statusLabel(report.status)),
            DetailRow('Luogo', report.place),
            DetailRow('Inizio', format.format(report.start.toLocal())),
            DetailRow(
              'Fine',
              report.end == null
                  ? '—'
                  : format.format(report.end!.toLocal()),
            ),
            DetailRow('Descrizione', report.description),
            if (report.planningNote?.isNotEmpty == true)
              DetailRow('Istruzioni ufficio', report.planningNote!),
            if (report.adminNote?.isNotEmpty == true)
              DetailRow('Nota amministratore', report.adminNote!),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({required this.report, required this.onTap, super.key});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(report.status).withAlpha(30),
                  foregroundColor: _statusColor(report.status),
                  child: Icon(_statusIcon(report.status)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.clientName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(report.start.toLocal()),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        report.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(_statusLabel(report.status)),
                          ),
                          if (report.planned)
                            const Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(Icons.event_available, size: 17),
                              label: Text('Assegnato'),
                            ),
                        ],
                      ),
                      if (report.planningNote?.isNotEmpty == true) ...[
                        const SizedBox(height: 7),
                        Text(
                          report.planningNote!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(report.editable ? Icons.edit_outlined : Icons.lock_outline),
              ],
            ),
          ),
        ),
      );
}

class ReportEditor extends StatefulWidget {
  const ReportEditor({
    required this.user,
    required this.service,
    this.report,
    super.key,
  });

  final AppUser user;
  final CloudService service;
  final Report? report;

  @override
  State<ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends State<ReportEditor> {
  final _key = GlobalKey<FormState>();
  final _place = TextEditingController();
  final _reference = TextEditingController();
  final _plate = TextEditingController();
  final _km = TextEditingController();
  final _description = TextEditingController();
  final _incomplete = TextEditingController();
  final _signature = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _picker = ImagePicker();
  final List<XFile> _photos = [];

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _vehicles = [];
  String? _clientId;
  String? _vehicleId;
  String _type = 'montaggio_posa';
  String _outcome = 'da_eseguire';
  late DateTime _start;
  DateTime? _end;
  bool _loading = true;
  bool _busy = false;

  Report? get report => widget.report;

  @override
  void initState() {
    super.initState();
    final current = report;
    _clientId = current?.clientId;
    _vehicleId = current?.vehicleId;
    _place.text = current?.place ?? '';
    _reference.text = current?.reference ?? '';
    _plate.text = current?.plate ?? '';
    _km.text = current?.km?.toString() ?? '';
    _description.text = current?.description ?? '';
    _incomplete.text = current?.incompleteNote ?? '';
    _type = current?.type ?? 'montaggio_posa';
    _outcome = current?.outcome ?? 'da_eseguire';
    _start = current?.start.toLocal() ?? DateTime.now();
    _end = current?.end?.toLocal();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.service.clients(),
        widget.service.vehicles(),
      ]);
      if (!mounted) return;
      setState(() {
        _clients = values[0];
        _vehicles = values[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(_clean(error));
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _reference.dispose();
    _plate.dispose();
    _km.dispose();
    _description.dispose();
    _incomplete.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file != null && mounted) setState(() => _photos.add(file));
  }

  Future<void> _save(bool submit) async {
    if (!_key.currentState!.validate()) return;
    if (_clientId == null) {
      _message('Seleziona il cliente.');
      return;
    }
    if (submit && _end == null) {
      _message('Per inviare serve l’ora di fine.');
      return;
    }
    if (submit && report?.signaturePath == null && _signature.isEmpty) {
      _message('Per inviare serve la firma cliente.');
      return;
    }

    setState(() => _busy = true);
    try {
      final draft = await widget.service.saveDraft(
        original: report,
        user: widget.user,
        clientId: _clientId!,
        place: _place.text,
        type: _type,
        start: _start,
        end: _end,
        description: _description.text,
        reference: _reference.text,
        vehicleId: _vehicleId,
        plate: _plate.text,
        km: int.tryParse(_km.text.trim()),
        outcome: _outcome,
        incompleteNote: _incomplete.text,
      );

      final id = '${draft['id']}';
      var signature =
          draft['firma_cliente_url'] as String? ?? report?.signaturePath;

      if (_signature.isNotEmpty) {
        final bytes = await _signature.toPngBytes(width: 1000, height: 450);
        if (bytes == null) throw StateError('Firma non disponibile.');
        signature = await widget.service.uploadSignature(
          widget.user.id,
          id,
          bytes,
        );
      }

      for (final photo in _photos) {
        await widget.service.uploadPhoto(
          widget.user.id,
          id,
          Uint8List.fromList(await photo.readAsBytes()),
        );
      }

      if (submit && signature == null) {
        throw StateError('Firma cliente non disponibile.');
      }
      if (signature != null) {
        await widget.service.updateSignature(
          reportId: id,
          version: (draft['versione'] as num?)?.toInt() ?? 1,
          signaturePath: signature,
          submit: submit,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message(_clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dateTime(bool start) async {
    final initial = start ? _start : (_end ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = result;
      } else {
        _end = result;
      }
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(report == null ? 'Nuovo rapportino' : 'Rapportino'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (report?.planningNote?.isNotEmpty == true) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.assignment_turned_in_outlined),
                        title: const Text('Istruzioni dell’ufficio'),
                        subtitle: Text(report!.planningNote!),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _clients.any(
                      (item) => '${item['id']}' == _clientId,
                    )
                        ? _clientId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Cliente *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: _clients
                        .map(
                          (item) => DropdownMenuItem(
                            value: '${item['id']}',
                            child: Text('${item['ragione_sociale']}'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _clientId = value),
                    validator: (value) =>
                        value == null ? 'Seleziona il cliente.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _place,
                    decoration: const InputDecoration(
                      labelText: 'Luogo / cantiere *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Indica il luogo.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reference,
                    decoration: const InputDecoration(
                      labelText: 'Riferimento appuntamento',
                      prefixIcon: Icon(Icons.event_note_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo intervento',
                      prefixIcon: Icon(Icons.handyman_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'montaggio_posa',
                        child: Text('Montaggio / posa'),
                      ),
                      DropdownMenuItem(
                        value: 'manutenzione_riparazione',
                        child: Text('Manutenzione / riparazione'),
                      ),
                      DropdownMenuItem(
                        value: 'sopralluogo',
                        child: Text('Sopralluogo'),
                      ),
                      DropdownMenuItem(
                        value: 'consegna_ritiro',
                        child: Text('Consegna / ritiro'),
                      ),
                      DropdownMenuItem(
                        value: 'lavorazione_officina',
                        child: Text('Lavorazione in officina'),
                      ),
                      DropdownMenuItem(
                        value: 'altro',
                        child: Text('Altro'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _type = value ?? 'altro'),
                  ),
                  const SizedBox(height: 14),
                  DateCard(
                    title: 'Inizio',
                    value: format.format(_start),
                    onTap: _busy ? null : () => _dateTime(true),
                  ),
                  const SizedBox(height: 10),
                  DateCard(
                    title: 'Fine',
                    value: _end == null ? 'Non impostata' : format.format(_end!),
                    onTap: _busy ? null : () => _dateTime(false),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _vehicles.any(
                      (item) => '${item['id']}' == _vehicleId,
                    )
                        ? _vehicleId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Mezzo',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Nessun mezzo'),
                      ),
                      ..._vehicles.map(
                        (item) => DropdownMenuItem(
                          value: '${item['id']}',
                          child: Text(
                            '${item['targa']} · ${item['descrizione']}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                              _vehicleId = value;
                              final found = _vehicles.where(
                                (item) => '${item['id']}' == value,
                              );
                              if (found.isNotEmpty) {
                                _plate.text = '${found.first['targa'] ?? ''}';
                              }
                            }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _plate,
                          decoration: const InputDecoration(labelText: 'Targa'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _km,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Km'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Lavoro eseguito *',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Descrivi il lavoro.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _outcome,
                    decoration: const InputDecoration(
                      labelText: 'Esito',
                      prefixIcon: Icon(Icons.fact_check_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'da_eseguire',
                        child: Text('Da eseguire'),
                      ),
                      DropdownMenuItem(
                        value: 'completato',
                        child: Text('Completato'),
                      ),
                      DropdownMenuItem(
                        value: 'da_completare',
                        child: Text('Da completare'),
                      ),
                      DropdownMenuItem(
                        value: 'materiale_mancante',
                        child: Text('Materiale mancante'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) =>
                            setState(() => _outcome = value ?? 'da_eseguire'),
                  ),
                  if (_outcome == 'da_completare' ||
                      _outcome == 'materiale_mancante') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _incomplete,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Cosa manca / cosa completare',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'Firma cliente',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Signature(
                      controller: _signature,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _signature.clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('CANCELLA'),
                      ),
                      if (report?.signaturePath != null)
                        const Expanded(
                          child: Text(
                            'Firma già salvata',
                            textAlign: TextAlign.end,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _photo,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      _photos.isEmpty
                          ? 'AGGIUNGI FOTO'
                          : 'FOTO DA INVIARE: ${_photos.length}',
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _save(false),
                    child: const Text('SALVA BOZZA'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _save(true),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_busy ? 'SALVATAGGIO…' : 'INVIA ALL’UFFICIO'),
                  ),
                ],
              ),
            ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    required this.user,
    required this.service,
    super.key,
  });

  final AppUser user;
  final CloudService service;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Map<String, dynamic>? _latest;
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _worksites = [];
  List<Map<String, dynamic>> _vehicles = [];
  String? _vehicleId;
  bool _transfer = false;
  bool _loading = true;
  bool _busy = false;
  final _reason = TextEditingController();

  bool get _inside => _latest?['tipo'] == 'entrata';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.service.latestAttendance(widget.user.id),
        widget.service.attendanceConfiguration(),
      ]);
      if (!mounted) return;
      final config = values[1] as Map<String, dynamic>;
      setState(() {
        _latest = values[0];
        _company = config['company'] as Map<String, dynamic>?;
        _worksites = List<Map<String, dynamic>>.from(config['worksites'] as List);
        _vehicles = List<Map<String, dynamic>>.from(config['vehicles'] as List);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(_clean(error));
    }
  }

  Future<void> _register() async {
    if (_transfer && _reason.text.trim().length < 3) {
      _message('Indica il motivo della trasferta.');
      return;
    }
    setState(() => _busy = true);
    try {
      final position = await widget.service.position();
      final reference = _transfer ? null : _nearest(position);
      final gpsCheck = _company?['controllo_gps_presenze'] == true;

      if (!_transfer && gpsCheck && reference == null) {
        throw StateError('Sede non configurata.');
      }
      if (!_transfer &&
          gpsCheck &&
          reference != null &&
          (reference['distance'] as double) > (reference['radius'] as double)) {
        throw StateError(
          'Sei fuori dall’area autorizzata di ${reference['name']}. '
          'Attiva la presenza in trasferta.',
        );
      }

      final type = _inside ? 'uscita' : 'entrata';
      await widget.service.registerAttendance(
        user: widget.user,
        type: type,
        position: position,
        mode: _transfer
            ? 'trasferta'
            : reference?['kind'] == 'cantiere'
                ? 'cantiere'
                : 'sede',
        worksiteId: reference?['kind'] == 'cantiere'
            ? reference!['id'] as String?
            : null,
        transferReason: _transfer ? _reason.text : null,
        vehicleId: _vehicleId,
        place: _transfer ? 'Trasferta' : reference?['name'] as String?,
      );

      _reason.clear();
      _transfer = false;
      await _load();
      _message(type == 'entrata' ? 'Entrata registrata.' : 'Uscita registrata.');
    } catch (error) {
      _message(_clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic>? _nearest(Position position) {
    final refs = <Map<String, dynamic>>[];

    void add(
      String kind,
      String? id,
      String name,
      Object? latitude,
      Object? longitude,
      Object? radius,
    ) {
      final lat = (latitude as num?)?.toDouble();
      final lon = (longitude as num?)?.toDouble();
      if (lat == null || lon == null) return;
      final allowed = (radius as num?)?.toDouble() ?? 200;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lon,
      );
      refs.add({
        'kind': kind,
        'id': id,
        'name': name,
        'radius': allowed,
        'distance': distance,
        'inside': distance <= allowed,
      });
    }

    final company = _company;
    if (company != null) {
      add(
        'sede',
        null,
        '${company['ragione_sociale'] ?? 'Sede aziendale'}',
        company['gps_latitudine'],
        company['gps_longitudine'],
        company['raggio_presenza_metri'],
      );
    }
    for (final site in _worksites) {
      add(
        'cantiere',
        site['id'] as String?,
        '${site['nome'] ?? 'Cantiere'}',
        site['gps_latitudine'],
        site['gps_longitudine'],
        site['raggio_presenza_metri'],
      );
    }
    if (refs.isEmpty) return null;
    refs.sort((a, b) {
      final inside = (b['inside'] == true ? 1 : 0)
          .compareTo(a['inside'] == true ? 1 : 0);
      if (inside != 0) return inside;
      return (a['distance'] as double).compareTo(b['distance'] as double);
    });
    return refs.first;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('${_latest?['registrata_at'] ?? ''}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenze'),
        actions: [
          IconButton(onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              (_inside ? Colors.green : Colors.blueGrey)
                                  .withAlpha(30),
                          foregroundColor:
                              _inside ? Colors.green : Colors.blueGrey,
                          child: Icon(_inside ? Icons.work : Icons.home_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _inside ? 'Sei presente' : 'Non sei in servizio',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date == null
                                    ? 'Nessuna registrazione'
                                    : 'Ultima: ${DateFormat('dd/MM HH:mm').format(date.toLocal())}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  value: _transfer,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _transfer = value),
                  title: const Text('Presenza in trasferta'),
                  subtitle: const Text(
                    'Attivala se non sei in sede o in un cantiere configurato.',
                  ),
                  secondary: const Icon(Icons.travel_explore_outlined),
                ),
                if (_transfer) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Motivo trasferta *',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: _vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Mezzo utilizzato',
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Nessun mezzo'),
                    ),
                    ..._vehicles.map(
                      (item) => DropdownMenuItem(
                        value: '${item['id']}',
                        child: Text(
                          '${item['targa']} · ${item['descrizione']}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _vehicleId = value),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _register,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_inside ? Icons.logout : Icons.login),
                  label: Text(
                    _busy
                        ? 'REGISTRAZIONE…'
                        : _inside
                            ? 'REGISTRA USCITA'
                            : 'REGISTRA ENTRATA',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Il GPS viene usato solo quando registri entrata o uscita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class CommunicationsPage extends StatefulWidget {
  const CommunicationsPage({
    required this.user,
    required this.service,
    super.key,
  });

  final AppUser user;
  final CloudService service;

  @override
  State<CommunicationsPage> createState() => _CommunicationsPageState();
}

class _CommunicationsPageState extends State<CommunicationsPage> {
  late Future<List<Communication>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.communications(widget.user.id);
  }

  Future<void> _refresh() async {
    final future = widget.service.communications(widget.user.id);
    setState(() => _future = future);
    await future;
  }

  Future<void> _open(Communication item) async {
    if (!item.read) {
      await widget.service.markCommunication(
        user: widget.user,
        communicationId: item.id,
        confirm: false,
      );
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: Text(item.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CHIUDI'),
          ),
          if (item.requiresConfirmation && !item.confirmed)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFERMO LETTURA'),
            ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.service.markCommunication(
        user: widget.user,
        communicationId: item.id,
        confirm: true,
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Comunicazioni'),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<List<Communication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: _clean(snapshot.error), retry: _refresh);
            }

            final items = snapshot.data ?? const [];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (items.isEmpty)
                    const EmptyView(
                      icon: Icons.notifications_none,
                      text: 'Nessuna comunicazione.',
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            onTap: () => _open(item),
                            leading: CircleAvatar(
                              backgroundColor:
                                  _priority(item.priority).withAlpha(30),
                              foregroundColor: _priority(item.priority),
                              child: Icon(
                                item.read
                                    ? Icons.mark_email_read_outlined
                                    : Icons.mark_email_unread_outlined,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.read
                                    ? FontWeight.w600
                                    : FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('dd/MM/yyyy HH:mm').format(item.published.toLocal())}\n'
                              '${item.message}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: item.confirmed
                                ? const Icon(Icons.verified, color: Colors.green)
                                : const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profilo')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFF12385B),
                      foregroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(
                        user.role == 'admin'
                            ? 'Amministratore'
                            : 'Dipendente',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Collegato al gestionale Windows'),
                subtitle: Text(
                  'Telefono e computer utilizzano lo stesso database Supabase.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('ESCI DALL’APP'),
            ),
          ],
        ),
      );
}

class DateCard extends StatelessWidget {
  const DateCard({
    required this.title,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.schedule),
          title: Text(title),
          subtitle: Text(value),
          trailing: const Icon(Icons.edit_calendar_outlined),
        ),
      );
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value),
          ],
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.text,
    super.key,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(icon, size: 58),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    required this.retry,
    super.key,
  });

  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: retry, child: const Text('RIPROVA')),
            ],
          ),
        ),
      );
}

String _clean(Object? error) => error
    .toString()
    .replaceFirst('Bad state: ', '')
    .replaceFirst('PostgrestException(message: ', '')
    .split(', code:')
    .first;

String _statusLabel(String value) => switch (value) {
      'bozza' => 'Bozza',
      'inviato' => 'Inviato',
      'approvato' => 'Approvato',
      'respinto' => 'Respinto',
      _ => value,
    };

Color _statusColor(String value) => switch (value) {
      'bozza' => Colors.blueGrey,
      'inviato' => Colors.blue,
      'approvato' => Colors.green,
      'respinto' => Colors.red,
      _ => Colors.grey,
    };

IconData _statusIcon(String value) => switch (value) {
      'bozza' => Icons.edit_note,
      'inviato' => Icons.outbox_outlined,
      'approvato' => Icons.verified_outlined,
      'respinto' => Icons.error_outline,
      _ => Icons.description_outlined,
    };

Color _priority(String value) => switch (value) {
      'urgente' => Colors.red,
      'alta' => Colors.orange,
      _ => Colors.blue,
    };
