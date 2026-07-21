import 'dart:io';

import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncConflictException extends AppException {
  const SyncConflictException()
      : super(
          'Il rapportino è stato modificato dall’ufficio. '
          'Aggiorna i dati prima di riprovare.',
        );
}

class RapportiniRemoteDataSource {
  const RapportiniRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Cliente>> fetchClienti() async {
    final rows = await _client
        .from('clienti')
        .select('id,ragione_sociale,indirizzo,referente,telefono')
        .order('ragione_sociale');
    return rows.map(Cliente.fromRemoteJson).toList(growable: false);
  }

  Future<Cliente> createCliente(Cliente cliente) async {
    final row = await _client
        .from('clienti')
        .insert(cliente.toRemoteMap())
        .select('id,ragione_sociale,indirizzo,referente,telefono')
        .single();
    return Cliente.fromRemoteJson(row);
  }

  Future<List<Map<String, dynamic>>> fetchRapportini(String dipendenteId) async {
    final rows = await _client
        .from('rapportini')
        .select()
        .eq('dipendente_id', dipendenteId)
        .order('data_ora_inizio', ascending: false);
    return rows;
  }

  Future<Map<String, dynamic>?> fetchRapportino(String id) async {
    final rows = await _client
        .from('rapportini')
        .select()
        .eq('id', id)
        .limit(1);
    return rows.isEmpty ? null : rows.single;
  }

  Future<Map<String, dynamic>> saveRemoteDraft(Rapportino report) async {
    final payload = report.toRemoteMap(remoteState: StatoRapportino.bozza);

    if (report.versioneRemota == 0) {
      return _client
          .from('rapportini')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
    }

    final rows = await _client
        .from('rapportini')
        .update(payload)
        .eq('id', report.id)
        .eq('versione', report.versioneRemota)
        .select();
    if (rows.isEmpty) throw const SyncConflictException();
    return rows.single;
  }

  Future<String> uploadSignature(Rapportino report) async {
    final localPath = report.firmaLocalePath;
    if (localPath == null) {
      throw const AppException('Firma locale non disponibile.');
    }
    final file = File(localPath);
    if (!await file.exists()) {
      throw const AppException('Il file della firma non è più disponibile.');
    }

    final remotePath =
        '${report.dipendenteId}/${report.id}/firma_cliente.png';
    await _client.storage.from('rapportini-firme').upload(
          remotePath,
          file,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
    return remotePath;
  }

  Future<String> uploadPhoto(Rapportino report, RapportinoFoto foto) async {
    final file = File(foto.localPath);
    if (!await file.exists()) {
      throw const AppException('Una fotografia locale non è più disponibile.');
    }
    final remotePath =
        '${report.dipendenteId}/${report.id}/${foto.id}.jpg';
    await _client.storage.from('rapportini-foto').upload(
          remotePath,
          file,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    await _client.from('rapportino_foto').upsert({
      'id': foto.id,
      'rapportino_id': report.id,
      'foto_url': remotePath,
    }, onConflict: 'id', ignoreDuplicates: true);
    return remotePath;
  }

  Future<Map<String, dynamic>> finalizeReport(Rapportino report) async {
    final payload = report.toRemoteMap(remoteState: report.stato);
    final rows = await _client
        .from('rapportini')
        .update(payload)
        .eq('id', report.id)
        .eq('versione', report.versioneRemota)
        .select();
    if (rows.isEmpty) throw const SyncConflictException();
    return rows.single;
  }
}
