import 'dart:typed_data';

import 'package:arte_in_ferro_rapportini/core/database/local_database.dart';
import 'package:arte_in_ferro_rapportini/core/media/media_service.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/data/datasources/rapportini_remote_data_source.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/repositories/rapportini_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineRapportiniRepository implements RapportiniRepository {
  OfflineRapportiniRepository({
    required LocalDatabase database,
    required RapportiniRemoteDataSource remote,
    required MediaService media,
    Connectivity? connectivity,
  })  : _database = database,
        _remote = remote,
        _media = media,
        _connectivity = connectivity ?? Connectivity();

  final LocalDatabase _database;
  final RapportiniRemoteDataSource _remote;
  final MediaService _media;
  final Connectivity _connectivity;

  @override
  Future<String?> capturePhoto(String rapportinoId) {
    return _media.captureAndCompressPhoto(rapportinoId);
  }

  @override
  Future<List<Cliente>> loadClienti({bool refresh = true}) async {
    if (refresh && await _hasConnection()) {
      try {
        final remoteClienti = await _remote.fetchClienti();
        await _database.replaceClienti(remoteClienti);
      } on Object {
        // La cache locale rimane utilizzabile in caso di errore cloud.
      }
    }
    return _database.listClienti();
  }

  @override
  Future<List<RapportinoFoto>> loadFoto(String rapportinoId) {
    return _database.listFoto(rapportinoId);
  }

  @override
  Future<List<Rapportino>> loadRapportini(String dipendenteId) {
    return _database.listRapportini(dipendenteId);
  }

  @override
  Future<void> saveRapportino(
    Rapportino report,
    List<RapportinoFoto> foto,
  ) async {
    final pending = report.copyWith(
      sincronizzazione: StatoSincronizzazione.daSincronizzare,
      clearSyncError: true,
    );
    await _database.upsertRapportino(pending, enqueue: true);
    for (final item in foto) {
      await _database.upsertFoto(item);
    }
  }

  @override
  Future<String> saveSignature(String rapportinoId, Uint8List bytes) {
    return _media.saveSignature(rapportinoId, bytes);
  }

  @override
  Future<SyncResult> sync(String dipendenteId) async {
    if (!await _hasConnection()) {
      return const SyncResult(synced: 0, failed: 0, offline: true);
    }

    try {
      final clienti = await _remote.fetchClienti();
      await _database.replaceClienti(clienti);
    } on Object {
      // La sincronizzazione dei rapportini può proseguire con la cache clienti.
    }

    var synced = 0;
    var failed = 0;
    final pending = await _database.listPendingRapportini(dipendenteId);
    for (final report in pending) {
      try {
        await _syncSingle(report);
        synced++;
      } on Object catch (error) {
        if (await _recoverCompletedSync(report)) {
          synced++;
        } else {
          failed++;
          await _database.markSyncFailed(report.id, _safeError(error));
        }
      }
    }

    await _pullRemote(dipendenteId);
    return SyncResult(synced: synced, failed: failed, offline: false);
  }

  Future<bool> _recoverCompletedSync(Rapportino original) async {
    try {
      final local = await _database.getRapportino(original.id) ?? original;
      final remote = await _remote.fetchRapportino(original.id);
      if (remote == null || !_sameBusinessData(local, remote)) return false;

      final recovered = local.copyWith(
        firmaRemotePath: remote['firma_cliente_url'] as String?,
        stato: StatoRapportino.fromDatabase(remote['stato'] as String),
        notaAmministratore: remote['nota_amministratore'] as String?,
        versioneRemota: remote['versione'] as int? ?? local.versioneRemota,
        sincronizzazione: StatoSincronizzazione.sincronizzato,
        clearSyncError: true,
      );
      await _database.markSyncSucceeded(recovered);
      return true;
    } on Object {
      return false;
    }
  }

  bool _sameBusinessData(
    Rapportino local,
    Map<String, dynamic> remote,
  ) {
    bool sameInstant(DateTime? left, Object? right) {
      if (left == null || right == null) return left == null && right == null;
      return left.toUtc().isAtSameMomentAs(DateTime.parse(right as String));
    }

    return remote['dipendente_id'] == local.dipendenteId &&
        remote['cliente_id'] == local.clienteId &&
        remote['luogo'] == local.luogo &&
        remote['rif_appuntamento'] == local.rifAppuntamento &&
        remote['tipologia_intervento'] == local.tipologia.databaseValue &&
        sameInstant(local.dataOraInizio, remote['data_ora_inizio']) &&
        sameInstant(local.dataOraFine, remote['data_ora_fine']) &&
        remote['descrizione'] == local.descrizione &&
        remote['stato'] == local.stato.databaseValue &&
        (local.stato == StatoRapportino.bozza ||
            remote['firma_cliente_url'] != null);
  }

  Future<void> _syncSingle(Rapportino original) async {
    var current = original.copyWith(
      sincronizzazione: StatoSincronizzazione.sincronizzazione,
    );
    await _database.upsertRapportino(current);

    final draftJson = await _remote.saveRemoteDraft(current);
    current = current.copyWith(
      versioneRemota: draftJson['versione'] as int? ?? 1,
    );

    if (current.firmaLocalePath != null && current.firmaRemotePath == null) {
      final remotePath = await _remote.uploadSignature(current);
      current = current.copyWith(firmaRemotePath: remotePath);
      await _database.upsertRapportino(current);
    }

    final foto = await _database.listFoto(current.id);
    for (final item in foto.where((element) => !element.sincronizzato)) {
      final path = await _remote.uploadPhoto(current, item);
      await _database.upsertFoto(item.markSynced(path));
    }

    final finalJson = await _remote.finalizeReport(current);
    current = current.copyWith(
      versioneRemota: finalJson['versione'] as int? ?? current.versioneRemota + 1,
      notaAmministratore: finalJson['nota_amministratore'] as String?,
      sincronizzazione: StatoSincronizzazione.sincronizzato,
      clearSyncError: true,
    );
    await _database.markSyncSucceeded(current);
  }

  Future<void> _pullRemote(String dipendenteId) async {
    try {
      final clienti = await _database.listClienti();
      final clienteNames = {for (final item in clienti) item.id: item.ragioneSociale};
      final rows = await _remote.fetchRapportini(dipendenteId);
      for (final row in rows) {
        final id = row['id'] as String;
        final local = await _database.getRapportino(id);
        if (local != null &&
            local.sincronizzazione != StatoSincronizzazione.sincronizzato) {
          continue;
        }

        final remote = _fromRemote(
          row,
          clienteNames[row['cliente_id']] ?? local?.clienteNome ?? 'Cliente',
          local,
        );
        await _database.upsertRapportino(remote);
      }
    } on Object {
      // Il push già completato non viene annullato se il refresh fallisce.
    }
  }

  Rapportino _fromRemote(
    Map<String, dynamic> json,
    String clienteNome,
    Rapportino? local,
  ) {
    DateTime? parseNullable(Object? value) {
      return value is String && value.isNotEmpty ? DateTime.parse(value) : null;
    }

    return Rapportino(
      id: json['id'] as String,
      dipendenteId: json['dipendente_id'] as String,
      clienteId: json['cliente_id'] as String,
      clienteNome: clienteNome,
      luogo: json['luogo'] as String,
      rifAppuntamento: json['rif_appuntamento'] as String?,
      tipologia: TipoIntervento.fromDatabase(
        json['tipologia_intervento'] as String,
      ),
      dataOraInizio: DateTime.parse(json['data_ora_inizio'] as String),
      dataOraFine: parseNullable(json['data_ora_fine']),
      descrizione: json['descrizione'] as String? ?? '',
      firmaLocalePath: local?.firmaLocalePath,
      firmaRemotePath: json['firma_cliente_url'] as String?,
      gpsLatitudine: (json['gps_latitudine'] as num?)?.toDouble(),
      gpsLongitudine: (json['gps_longitudine'] as num?)?.toDouble(),
      gpsPrecisioneMetri: (json['gps_precisione_metri'] as num?)?.toDouble(),
      gpsRilevatoAt: parseNullable(json['gps_rilevato_at']),
      stato: StatoRapportino.fromDatabase(json['stato'] as String),
      notaAmministratore: json['nota_amministratore'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      versioneRemota: json['versione'] as int? ?? 1,
      sincronizzazione: StatoSincronizzazione.sincronizzato,
    );
  }

  Future<bool> _hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _safeError(Object error) {
    final message = error.toString();
    return message.length > 300 ? '${message.substring(0, 300)}…' : message;
  }
}
