import 'dart:io';
import 'dart:typed_data';

import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:arte_in_ferro_rapportini/core/gps/location_service.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/company/data/company_service.dart';
import 'package:arte_in_ferro_rapportini/features/materials/presentation/material_request_page.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/cubit/rapportini_cubit.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/cubit/rapportini_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class RapportinoFormPage extends StatefulWidget {
  const RapportinoFormPage({
    required this.user,
    this.rapportino,
    super.key,
  });

  final AppUser user;
  final Rapportino? rapportino;

  @override
  State<RapportinoFormPage> createState() => _RapportinoFormPageState();
}

class _RapportinoFormPageState extends State<RapportinoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late final String _id;
  late final TextEditingController _luogoController;
  late final TextEditingController _mapsUrlController;
  late final TextEditingController _riferimentoController;
  late final TextEditingController _targaController;
  late final TextEditingController _kmController;
  late final TextEditingController _descrizioneController;
  late final TextEditingController _incompleteNoteController;
  late DateTime _inizio;
  DateTime? _fine;
  String? _clienteId;
  String? _mezzoId;
  List<String> _collaboratoriIds = [];
  List<Map<String, dynamic>> _mezzi = [];
  List<Map<String, dynamic>> _dipendenti = [];
  bool _loadingCompanyData = true;
  late TipoIntervento _tipologia;
  late EsitoLavoro _esitoLavoro;
  List<RapportinoFoto> _foto = [];
  String? _firmaPath;
  bool _signatureChanged = false;
  bool _busy = false;
  String? _busyMessage;

  @override
  void initState() {
    super.initState();
    final report = widget.rapportino;
    _id = report?.id ?? _uuid.v4();
    _luogoController = TextEditingController(text: report?.luogo);
    _mapsUrlController = TextEditingController(text: report?.mapsUrl);
    _riferimentoController = TextEditingController(
      text: report?.rifAppuntamento,
    );
    _targaController = TextEditingController(text: report?.targaMezzo);
    _kmController = TextEditingController(text: report?.kmMezzo?.toString());
    _descrizioneController = TextEditingController(text: report?.descrizione);
    _incompleteNoteController = TextEditingController(
      text: report?.notaLavoroIncompleto,
    );
    _inizio = report?.dataOraInizio.toLocal() ?? DateTime.now();
    _fine = report?.dataOraFine?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    _clienteId = report?.clienteId;
    _mezzoId = report?.mezzoId;
    _collaboratoriIds = [...?report?.collaboratoriIds];
    _tipologia = report?.tipologia ?? TipoIntervento.montaggioPosa;
    _esitoLavoro = report?.esitoLavoro ?? EsitoLavoro.daEseguire;
    _firmaPath = report?.firmaLocalePath;
    _loadCompanyData();

    if (report != null) {
      context.read<RapportiniCubit>().loadFoto(report.id).then((value) {
        if (mounted) setState(() => _foto = value);
      });
    }
  }

  @override
  void dispose() {
    _luogoController.dispose();
    _mapsUrlController.dispose();
    _riferimentoController.dispose();
    _targaController.dispose();
    _kmController.dispose();
    _descrizioneController.dispose();
    _incompleteNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clienti = context.select(
      (RapportiniCubit cubit) => cubit.state.clienti,
    );
    if (_clienteId == null && clienti.isNotEmpty) {
      _clienteId = clienti.first.id;
    }
    var selectedClientName = '';
    for (final cliente in clienti) {
      if (cliente.id == _clienteId) {
        selectedClientName = cliente.ragioneSociale;
        break;
      }
    }

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.rapportino == null ? 'Nuovo rapportino' : 'Modifica rapportino',
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (widget.rapportino?.pianificato == true) ...[
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.event_available_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Lavoro assegnato dall’ufficio',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              if (widget.rapportino?.notePianificazione?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(widget.rapportino!.notePianificazione!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _SectionTitle(
                      number: 1,
                      title: 'Cliente e intervento',
                    ),
                    Autocomplete<Cliente>(
                      initialValue: TextEditingValue(text: selectedClientName),
                      displayStringForOption: (cliente) => cliente.ragioneSociale,
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text.trim().toLowerCase();
                        if (query.isEmpty) return clienti.take(20);
                        return clienti.where((cliente) {
                          final search = [
                            cliente.ragioneSociale,
                            cliente.referente ?? '',
                            cliente.indirizzo,
                          ].join(' ').toLowerCase();
                          return search.contains(query);
                        }).take(30);
                      },
                      onSelected: (cliente) =>
                          setState(() => _clienteId = cliente.id),
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) => TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Cliente *',
                          hintText: 'Digita nome, cognome, referente o località',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => _clienteId = null,
                        validator: (_) => _clienteId == null
                            ? 'Seleziona un cliente dai risultati'
                            : null,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _createCliente,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Nuovo cliente'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TipoIntervento>(
                      initialValue: _tipologia,
                      decoration: const InputDecoration(
                        labelText: 'Tipo intervento *',
                        prefixIcon: Icon(Icons.handyman_outlined),
                      ),
                      items: TipoIntervento.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _tipologia = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _luogoController,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Luogo / cantiere',
                        helperText: 'Scrivi il luogo oppure usa Google Maps',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: _validateLuogo,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _useCurrentPosition,
                          icon: const Icon(Icons.my_location_outlined),
                          label: const Text('USA POSIZIONE ATTUALE'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _openGoogleMaps,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('APRI GOOGLE MAPS'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _mapsUrlController,
                      enabled: !_busy,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link Google Maps (facoltativo)',
                        hintText: 'https://maps.app.goo.gl/…',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        return _isValidMapsUrl(text)
                            ? null
                            : 'Inserisci un link Google Maps valido';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _riferimentoController,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Riferimento appuntamento',
                        prefixIcon: Icon(Icons.event_note_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _mezzoId,
                      decoration: InputDecoration(
                        labelText: 'Mezzo utilizzato',
                        prefixIcon:
                            const Icon(Icons.local_shipping_outlined),
                        helperText: _loadingCompanyData
                            ? 'Caricamento mezzi…'
                            : 'Seleziona un mezzo registrato in azienda',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Nessun mezzo'),
                        ),
                        ..._mezzi.map(
                          (mezzo) => DropdownMenuItem<String?>(
                            value: mezzo['id'] as String,
                            child: Text(
                              _vehicleLabel(mezzo),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _busy || _loadingCompanyData
                          ? null
                          : (value) {
                              setState(() {
                                _mezzoId = value;
                                Map<String, dynamic>? selected;
                                for (final item in _mezzi) {
                                  if (item['id'] == value) {
                                    selected = item;
                                    break;
                                  }
                                }
                                _targaController.text =
                                    selected?['targa']?.toString() ?? '';
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kmController,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Chilometri mezzo',
                        suffixText: 'km',
                        prefixIcon: Icon(Icons.speed_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final km = int.tryParse(value.trim());
                        return km == null || km < 0
                            ? 'Inserisci chilometri validi'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Collaboratori presenti in cantiere',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_loadingCompanyData)
                      const LinearProgressIndicator()
                    else if (_availableCollaborators.isEmpty)
                      const Text('Nessun altro collaboratore disponibile.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableCollaborators.map((employee) {
                          final id = employee['id'] as String;
                          return FilterChip(
                            label: Text(
                              employee['nome_cognome']?.toString() ??
                                  employee['email']?.toString() ??
                                  'Collaboratore',
                            ),
                            selected: _collaboratoriIds.contains(id),
                            onSelected: _busy || !_canEditTeam
                                ? null
                                : (selected) => setState(() {
                                      if (selected) {
                                        _collaboratoriIds.add(id);
                                      } else {
                                        _collaboratoriIds.remove(id);
                                      }
                                    }),
                          );
                        }).toList(growable: false),
                      ),
                    const SizedBox(height: 24),
                    const _SectionTitle(number: 2, title: 'Data e orari'),
                    _DateTimeField(
                      label: 'Inizio *',
                      value: _inizio,
                      enabled: !_busy,
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                    const SizedBox(height: 12),
                    _DateTimeField(
                      label: 'Fine *',
                      value: _fine,
                      enabled: !_busy,
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                    if (_fine != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Totale: ${_hoursLabel()}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _SectionTitle(number: 3, title: 'Lavoro svolto'),
                    TextFormField(
                      controller: _descrizioneController,
                      enabled: !_busy,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione attività *',
                        alignLabelWithHint: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<EsitoLavoro>(
                      initialValue: _esitoLavoro,
                      decoration: const InputDecoration(
                        labelText: 'Esito del lavoro',
                        prefixIcon: Icon(Icons.fact_check_outlined),
                      ),
                      items: EsitoLavoro.values
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ))
                          .toList(growable: false),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                                if (value != null) _esitoLavoro = value;
                              }),
                    ),
                    if (_esitoLavoro == EsitoLavoro.daCompletare ||
                        _esitoLavoro == EsitoLavoro.materialeMancante) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _incompleteNoteController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: _esitoLavoro == EsitoLavoro.materialeMancante
                              ? 'Quale materiale manca? *'
                              : 'Cosa resta da completare? *',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Inserisci una breve spiegazione'
                            : null,
                      ),
                    ],
                    if (_esitoLavoro == EsitoLavoro.materialeMancante) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => MaterialRequestPage(
                                      user: widget.user,
                                      reportId:
                                          (widget.rapportino?.versioneRemota ?? 0) > 0
                                              ? _id
                                              : null,
                                    ),
                                  ),
                                ),
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('INSERISCI MATERIALI MANCANTI'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _SectionTitle(number: 4, title: 'Foto cantiere'),
                    _PhotoStrip(foto: _foto),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _choosePhotoSource,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('AGGIUNGI FOTO'),
                    ),
                    const SizedBox(height: 24),
                    const _SectionTitle(number: 5, title: 'Firma cliente'),
                    _SignaturePreview(
                      localPath: _firmaPath,
                      hasRemoteSignature:
                          widget.rapportino?.firmaRemotePath != null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _captureSignature,
                      icon: const Icon(Icons.draw_outlined),
                      label: Text(
                        _firmaPath == null ? 'RACCOGLI FIRMA' : 'RIFAI FIRMA',
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _save(StatoRapportino.inviato),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('SALVA E INVIA'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _save(StatoRapportino.bozza),
                      child: const Text('SALVA COME BOZZA'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La posizione GPS viene rilevata al salvataggio. Se non '
                      'c’è rete, il rapportino resta sul telefono e sarà inviato '
                      'automaticamente al prossimo tentativo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 14),
                              Text(_busyMessage ?? 'Salvataggio…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obbligatorio' : null;
  }

  String? _validateLuogo(String? value) {
    final text = value?.trim() ?? '';
    if (text.length >= 2) return null;
    if (_isValidMapsUrl(_mapsUrlController.text.trim())) return null;
    return 'Scrivi il luogo oppure inserisci un link Google Maps';
  }

  bool _isValidMapsUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    return host.contains('google.') ||
        host == 'maps.app.goo.gl' ||
        host.endsWith('.google.com');
  }

  Future<void> _useCurrentPosition() async {
    _setBusy(true, 'Rilevamento posizione…');
    try {
      final location = await context.read<LocationService>().capture();
      final url = 'https://www.google.com/maps/search/?api=1&query='
          '${location.latitude},${location.longitude}';
      if (!mounted) return;
      setState(() {
        _mapsUrlController.text = url;
        if (_luogoController.text.trim().isEmpty) {
          _luogoController.text = 'Posizione Google Maps';
        }
      });
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openGoogleMaps() async {
    final saved = _mapsUrlController.text.trim();
    final Uri uri;
    if (_isValidMapsUrl(saved)) {
      uri = Uri.parse(saved);
    } else {
      final query = _luogoController.text.trim();
      uri = Uri.https(
        'www.google.com',
        '/maps/search/',
        {'api': '1', 'query': query.isEmpty ? 'Italia' : query},
      );
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showError(const AppException('Non riesco ad aprire Google Maps.'));
    }
  }

  Future<void> _createCliente() async {
    final ragione = TextEditingController();
    final indirizzo = TextEditingController();
    final referente = TextEditingController();
    final telefono = TextEditingController();
    final key = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuovo cliente'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: ragione,
                  decoration: const InputDecoration(labelText: 'Ragione sociale *'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Inserisci almeno 2 caratteri'
                      : null,
                ),
                TextFormField(
                  controller: indirizzo,
                  decoration: const InputDecoration(labelText: 'Indirizzo *'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Inserisci l’indirizzo'
                      : null,
                ),
                TextFormField(
                  controller: referente,
                  decoration: const InputDecoration(labelText: 'Referente'),
                ),
                TextFormField(
                  controller: telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Crea cliente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _setBusy(true, 'Creazione cliente…');
    try {
      final created = await context.read<RapportiniCubit>().createCliente(
            Cliente(
              id: _uuid.v4(),
              ragioneSociale: ragione.text.trim(),
              indirizzo: indirizzo.text.trim(),
              referente: _emptyToNull(referente.text),
              telefono: _emptyToNull(telefono.text),
            ),
          );
      if (mounted) setState(() => _clienteId = created.id);
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
      ragione.dispose();
      indirizzo.dispose();
      referente.dispose();
      telefono.dispose();
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == 'camera') await _capturePhoto();
    if (source == 'gallery') await _selectPhoto();
  }

  Future<void> _selectPhoto() async {
    _setBusy(true, 'Importazione fotografia…');
    try {
      final path = await context.read<RapportiniCubit>().selectPhoto(_id);
      if (path != null && mounted) {
        setState(() {
          _foto = [
            ..._foto,
            RapportinoFoto(
              id: _uuid.v4(),
              rapportinoId: _id,
              localPath: path,
              createdAt: DateTime.now(),
            ),
          ];
        });
      }
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _capturePhoto() async {
    _setBusy(true, 'Ottimizzazione fotografia…');
    try {
      final path = await context.read<RapportiniCubit>().capturePhoto(_id);
      if (path != null && mounted) {
        setState(() {
          _foto = [
            ..._foto,
            RapportinoFoto(
              id: _uuid.v4(),
              rapportinoId: _id,
              localPath: path,
              createdAt: DateTime.now(),
            ),
          ];
        });
      }
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _captureSignature() async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Firma del cliente'),
        content: SizedBox(
          width: 520,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueGrey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.clear,
            child: const Text('CANCELLA FIRMA'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.isEmpty) return;
              final png = await controller.toPngBytes();
              if (png != null && dialogContext.mounted) {
                Navigator.of(dialogContext).pop(png);
              }
            },
            child: const Text('CONFERMA'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (bytes == null || !mounted) return;
    _setBusy(true, 'Salvataggio firma…');
    try {
      final path = await context.read<RapportiniCubit>().saveSignature(
            _id,
            bytes,
          );
      if (mounted) {
        setState(() {
          _firmaPath = path;
          _signatureChanged = true;
        });
      }
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _save(StatoRapportino state) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fine == null || !_fine!.isAfter(_inizio)) {
      _showError(const AppException('L’orario di fine deve essere dopo l’inizio.'));
      return;
    }
    final hasSignature = _firmaPath != null ||
        (!_signatureChanged && widget.rapportino?.firmaRemotePath != null);
    if (state == StatoRapportino.inviato && !hasSignature) {
      _showError(const AppException('Raccogli la firma prima dell’invio.'));
      return;
    }

    _setBusy(true, 'Rilevamento posizione GPS…');
    try {
      final location = await context.read<LocationService>().capture();
      if (!mounted) return;
      _setBusy(true, 'Salvataggio locale…');
      final existing = widget.rapportino;
      final cliente = _findCliente(
        context.read<RapportiniCubit>().state,
        _clienteId!,
      );
      final now = DateTime.now();
      final report = Rapportino(
        id: _id,
        dipendenteId: existing?.dipendenteId ?? widget.user.id,
        clienteId: cliente.id,
        clienteNome: cliente.ragioneSociale,
        luogo: _luogoController.text.trim().isEmpty
            ? 'Posizione Google Maps'
            : _luogoController.text.trim(),
        mapsUrl: _emptyToNull(_mapsUrlController.text),
        rifAppuntamento: _emptyToNull(_riferimentoController.text),
        mezzoId: _mezzoId,
        targaMezzo: _emptyToNull(_targaController.text)?.toUpperCase(),
        kmMezzo: int.tryParse(_kmController.text.trim()),
        collaboratoriIds: _collaboratoriIds,
        tipologia: _tipologia,
        dataOraInizio: _inizio,
        dataOraFine: _fine,
        descrizione: _descrizioneController.text.trim(),
        firmaLocalePath: _firmaPath,
        firmaRemotePath:
            _signatureChanged ? null : existing?.firmaRemotePath,
        gpsLatitudine: location.latitude,
        gpsLongitudine: location.longitude,
        gpsPrecisioneMetri: location.accuracy,
        gpsRilevatoAt: location.capturedAt,
        stato: state,
        notaAmministratore: existing?.notaAmministratore,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        versioneRemota: existing?.versioneRemota ?? 0,
        pianificato: existing?.pianificato ?? false,
        notePianificazione: existing?.notePianificazione,
        esitoLavoro: _esitoLavoro,
        notaLavoroIncompleto: _emptyToNull(_incompleteNoteController.text),
      );
      await context.read<RapportiniCubit>().save(report, _foto);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Cliente _findCliente(RapportiniState state, String id) {
    return state.clienti.firstWhere((item) => item.id == id);
  }

  List<Map<String, dynamic>> get _availableCollaborators => _dipendenti
      .where((employee) =>
          employee['id'] !=
          (widget.rapportino?.dipendenteId ?? widget.user.id))
      .toList(growable: false);

  bool get _canEditTeam => widget.rapportino == null ||
      widget.rapportino!.dipendenteId == widget.user.id;

  Future<void> _loadCompanyData() async {
    try {
      final service = CompanyService(Supabase.instance.client);
      final results = await Future.wait([
        service.loadVehicles(),
        service.loadEmployees(),
      ]);
      if (!mounted) return;
      setState(() {
        _mezzi = results[0];
        _dipendenti = results[1];
        _loadingCompanyData = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingCompanyData = false);
      _showError(
        AppException(
          'Non riesco a caricare mezzi e collaboratori: $error',
        ),
      );
    }
  }

  String _vehicleLabel(Map<String, dynamic> vehicle) {
    final plate = vehicle['targa']?.toString() ?? '';
    final description = vehicle['descrizione']?.toString() ?? '';
    final model = [vehicle['marca'], vehicle['modello']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ');
    return [plate, description, model]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ');
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _inizio : _fine ?? _inizio;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _inizio = value;
        if (_fine == null || !_fine!.isAfter(value)) {
          _fine = value.add(const Duration(hours: 1));
        }
      } else {
        _fine = value;
      }
    });
  }

  String _hoursLabel() {
    final minutes = _fine!.difference(_inizio).inMinutes;
    if (minutes <= 0) return 'orario non valido';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  void _setBusy(bool value, [String? message]) {
    if (!mounted) return;
    setState(() {
      _busy = value;
      _busyMessage = value ? message : null;
    });
  }

  void _showError(Object error) {
    if (!mounted) return;
    final raw = error is AppException ? error.message : error.toString();
    final message = raw.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              child: Text('$number', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      );
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.schedule),
            suffixIcon: const Icon(Icons.edit_calendar_outlined),
            enabled: enabled,
          ),
          child: Text(
            value == null
                ? 'Non impostato'
                : DateFormat('dd/MM/yyyy HH:mm').format(value!),
          ),
        ),
      );
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.foto});

  final List<RapportinoFoto> foto;

  @override
  Widget build(BuildContext context) {
    if (foto.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_camera_back_outlined),
              SizedBox(width: 8),
              Text('Nessuna fotografia'),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: foto.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = File(foto[index].localPath);
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 112,
              child: FutureBuilder<bool>(
                future: file.exists(),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return Image.file(file, fit: BoxFit.cover);
                  }
                  return const ColoredBox(
                    color: Colors.white,
                    child: Icon(Icons.cloud_done_outlined),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({
    required this.localPath,
    required this.hasRemoteSignature,
  });

  final String? localPath;
  final bool hasRemoteSignature;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: path != null
          ? Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('Firma non leggibile'),
            )
          : hasRemoteSignature
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_outlined),
                    SizedBox(width: 8),
                    Text('Firma già archiviata'),
                  ],
                )
              : const Text('Firma non acquisita'),
    );
  }
}
