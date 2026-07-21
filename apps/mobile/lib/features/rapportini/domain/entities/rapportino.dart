import 'dart:convert';

import 'package:equatable/equatable.dart';

enum TipoIntervento {
  montaggioPosa('montaggio_posa', 'Montaggio / posa'),
  manutenzioneRiparazione(
    'manutenzione_riparazione',
    'Manutenzione / riparazione',
  ),
  sopralluogo('sopralluogo', 'Sopralluogo'),
  consegnaRitiro('consegna_ritiro', 'Consegna / ritiro'),
  lavorazioneOfficina('lavorazione_officina', 'Lavorazione in officina'),
  altro('altro', 'Altro');

  const TipoIntervento(this.databaseValue, this.label);

  factory TipoIntervento.fromDatabase(String value) {
    return values.firstWhere((item) => item.databaseValue == value);
  }

  final String databaseValue;
  final String label;
}

enum StatoRapportino {
  bozza('bozza', 'Bozza'),
  inviato('inviato', 'Inviato'),
  approvato('approvato', 'Approvato'),
  respinto('respinto', 'Respinto');

  const StatoRapportino(this.databaseValue, this.label);

  factory StatoRapportino.fromDatabase(String value) {
    return values.firstWhere((item) => item.databaseValue == value);
  }

  final String databaseValue;
  final String label;

  bool get editable => this == bozza || this == respinto;
}

enum StatoSincronizzazione {
  sincronizzato,
  daSincronizzare,
  sincronizzazione,
  errore;

  String get databaseValue => name;

  factory StatoSincronizzazione.fromDatabase(String? value) {
    return values.firstWhere(
      (item) => item.databaseValue == value,
      orElse: () => StatoSincronizzazione.daSincronizzare,
    );
  }
}

class Rapportino extends Equatable {
  const Rapportino({
    required this.id,
    required this.dipendenteId,
    required this.clienteId,
    required this.clienteNome,
    required this.luogo,
    required this.tipologia,
    required this.dataOraInizio,
    required this.descrizione,
    required this.stato,
    required this.createdAt,
    required this.updatedAt,
    this.rifAppuntamento,
    this.mezzoId,
    this.targaMezzo,
    this.kmMezzo,
    this.collaboratoriIds = const [],
    this.dataOraFine,
    this.firmaLocalePath,
    this.firmaRemotePath,
    this.gpsLatitudine,
    this.gpsLongitudine,
    this.gpsPrecisioneMetri,
    this.gpsRilevatoAt,
    this.notaAmministratore,
    this.versioneRemota = 0,
    this.sincronizzazione = StatoSincronizzazione.daSincronizzare,
    this.erroreSincronizzazione,
  });

  factory Rapportino.fromLocalMap(Map<String, Object?> map) {
    return Rapportino(
      id: map['id']! as String,
      dipendenteId: map['dipendente_id']! as String,
      clienteId: map['cliente_id']! as String,
      clienteNome: map['cliente_nome'] as String? ?? 'Cliente',
      luogo: map['luogo']! as String,
      rifAppuntamento: map['rif_appuntamento'] as String?,
      mezzoId: map['mezzo_id'] as String?,
      targaMezzo: map['targa_mezzo'] as String?,
      kmMezzo: map['km_mezzo'] as int?,
      collaboratoriIds: _stringList(map['collaboratori_ids']),
      tipologia: TipoIntervento.fromDatabase(map['tipologia']! as String),
      dataOraInizio: DateTime.parse(map['data_ora_inizio']! as String),
      dataOraFine: _dateOrNull(map['data_ora_fine']),
      descrizione: map['descrizione'] as String? ?? '',
      firmaLocalePath: map['firma_locale_path'] as String?,
      firmaRemotePath: map['firma_remote_path'] as String?,
      gpsLatitudine: (map['gps_latitudine'] as num?)?.toDouble(),
      gpsLongitudine: (map['gps_longitudine'] as num?)?.toDouble(),
      gpsPrecisioneMetri: (map['gps_precisione_metri'] as num?)?.toDouble(),
      gpsRilevatoAt: _dateOrNull(map['gps_rilevato_at']),
      stato: StatoRapportino.fromDatabase(map['stato']! as String),
      notaAmministratore: map['nota_amministratore'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      versioneRemota: map['versione_remota'] as int? ?? 0,
      sincronizzazione: StatoSincronizzazione.fromDatabase(
        map['sync_status'] as String?,
      ),
      erroreSincronizzazione: map['sync_error'] as String?,
    );
  }

  final String id;
  final String dipendenteId;
  final String clienteId;
  final String clienteNome;
  final String luogo;
  final String? rifAppuntamento;
  final String? mezzoId;
  final String? targaMezzo;
  final int? kmMezzo;
  final List<String> collaboratoriIds;
  final TipoIntervento tipologia;
  final DateTime dataOraInizio;
  final DateTime? dataOraFine;
  final String descrizione;
  final String? firmaLocalePath;
  final String? firmaRemotePath;
  final double? gpsLatitudine;
  final double? gpsLongitudine;
  final double? gpsPrecisioneMetri;
  final DateTime? gpsRilevatoAt;
  final StatoRapportino stato;
  final String? notaAmministratore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int versioneRemota;
  final StatoSincronizzazione sincronizzazione;
  final String? erroreSincronizzazione;

  double get oreTotali {
    final end = dataOraFine;
    if (end == null) return 0;
    return end.difference(dataOraInizio).inMinutes / 60;
  }

  Map<String, Object?> toLocalMap() => {
        'id': id,
        'dipendente_id': dipendenteId,
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'luogo': luogo,
        'rif_appuntamento': rifAppuntamento,
        'mezzo_id': mezzoId,
        'targa_mezzo': targaMezzo,
        'km_mezzo': kmMezzo,
        'collaboratori_ids': jsonEncode(collaboratoriIds),
        'tipologia': tipologia.databaseValue,
        'data_ora_inizio': dataOraInizio.toUtc().toIso8601String(),
        'data_ora_fine': dataOraFine?.toUtc().toIso8601String(),
        'descrizione': descrizione,
        'firma_locale_path': firmaLocalePath,
        'firma_remote_path': firmaRemotePath,
        'gps_latitudine': gpsLatitudine,
        'gps_longitudine': gpsLongitudine,
        'gps_precisione_metri': gpsPrecisioneMetri,
        'gps_rilevato_at': gpsRilevatoAt?.toUtc().toIso8601String(),
        'stato': stato.databaseValue,
        'nota_amministratore': notaAmministratore,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'versione_remota': versioneRemota,
        'sync_status': sincronizzazione.databaseValue,
        'sync_error': erroreSincronizzazione,
      };

  Map<String, Object?> toRemoteMap({required StatoRapportino remoteState}) => {
        'id': id,
        'dipendente_id': dipendenteId,
        'cliente_id': clienteId,
        'luogo': luogo,
        'rif_appuntamento': rifAppuntamento,
        'mezzo_id': mezzoId,
        'targa_mezzo': targaMezzo,
        'km_mezzo': kmMezzo,
        'tipologia_intervento': tipologia.databaseValue,
        'data_ora_inizio': dataOraInizio.toUtc().toIso8601String(),
        'data_ora_fine': dataOraFine?.toUtc().toIso8601String(),
        'descrizione': descrizione,
        'firma_cliente_url': firmaRemotePath,
        'gps_latitudine': gpsLatitudine,
        'gps_longitudine': gpsLongitudine,
        'gps_precisione_metri': gpsPrecisioneMetri,
        'gps_rilevato_at': gpsRilevatoAt?.toUtc().toIso8601String(),
        'stato': remoteState.databaseValue,
      };

  Rapportino copyWith({
    String? firmaLocalePath,
    String? firmaRemotePath,
    StatoRapportino? stato,
    String? notaAmministratore,
    int? versioneRemota,
    StatoSincronizzazione? sincronizzazione,
    String? erroreSincronizzazione,
    bool clearSyncError = false,
  }) {
    return Rapportino(
      id: id,
      dipendenteId: dipendenteId,
      clienteId: clienteId,
      clienteNome: clienteNome,
      luogo: luogo,
      rifAppuntamento: rifAppuntamento,
      mezzoId: mezzoId,
      targaMezzo: targaMezzo,
      kmMezzo: kmMezzo,
      collaboratoriIds: collaboratoriIds,
      tipologia: tipologia,
      dataOraInizio: dataOraInizio,
      dataOraFine: dataOraFine,
      descrizione: descrizione,
      firmaLocalePath: firmaLocalePath ?? this.firmaLocalePath,
      firmaRemotePath: firmaRemotePath ?? this.firmaRemotePath,
      gpsLatitudine: gpsLatitudine,
      gpsLongitudine: gpsLongitudine,
      gpsPrecisioneMetri: gpsPrecisioneMetri,
      gpsRilevatoAt: gpsRilevatoAt,
      stato: stato ?? this.stato,
      notaAmministratore: notaAmministratore ?? this.notaAmministratore,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      versioneRemota: versioneRemota ?? this.versioneRemota,
      sincronizzazione: sincronizzazione ?? this.sincronizzazione,
      erroreSincronizzazione:
          clearSyncError ? null : erroreSincronizzazione ?? this.erroreSincronizzazione,
    );
  }

  @override
  List<Object?> get props => [
        id,
        dipendenteId,
        clienteId,
        clienteNome,
        luogo,
        rifAppuntamento,
        mezzoId,
        targaMezzo,
        kmMezzo,
        collaboratoriIds,
        tipologia,
        dataOraInizio,
        dataOraFine,
        descrizione,
        firmaLocalePath,
        firmaRemotePath,
        gpsLatitudine,
        gpsLongitudine,
        gpsPrecisioneMetri,
        gpsRilevatoAt,
        stato,
        notaAmministratore,
        createdAt,
        updatedAt,
        versioneRemota,
        sincronizzazione,
        erroreSincronizzazione,
      ];
}

List<String> _stringList(Object? value) {
  if (value is! String || value.isEmpty) return const [];
  try {
    return List<String>.from(jsonDecode(value) as List);
  } on Object {
    return const [];
  }
}

class RapportinoFoto extends Equatable {
  const RapportinoFoto({
    required this.id,
    required this.rapportinoId,
    required this.localPath,
    required this.createdAt,
    this.remotePath,
    this.sincronizzato = false,
  });

  factory RapportinoFoto.fromLocalMap(Map<String, Object?> map) {
    return RapportinoFoto(
      id: map['id']! as String,
      rapportinoId: map['rapportino_id']! as String,
      localPath: map['local_path']! as String,
      remotePath: map['remote_path'] as String?,
      sincronizzato: (map['sincronizzato'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }

  final String id;
  final String rapportinoId;
  final String localPath;
  final String? remotePath;
  final bool sincronizzato;
  final DateTime createdAt;

  Map<String, Object?> toLocalMap() => {
        'id': id,
        'rapportino_id': rapportinoId,
        'local_path': localPath,
        'remote_path': remotePath,
        'sincronizzato': sincronizzato ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  RapportinoFoto markSynced(String path) => RapportinoFoto(
        id: id,
        rapportinoId: rapportinoId,
        localPath: localPath,
        remotePath: path,
        sincronizzato: true,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        rapportinoId,
        localPath,
        remotePath,
        sincronizzato,
        createdAt,
      ];
}

DateTime? _dateOrNull(Object? value) {
  return value is String && value.isNotEmpty ? DateTime.parse(value) : null;
}
