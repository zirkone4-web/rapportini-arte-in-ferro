import 'package:arte_in_ferro_rapportini/core/gps/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyService {
  CompanyService(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> loadVehicles() async {
    final rows = await _client
        .from('mezzi')
        .select('id,targa,descrizione,marca,modello,km_attuali')
        .eq('attivo', true)
        .order('descrizione');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> latestAttendance(String employeeId) async {
    final rows = await _client
        .from('timbrature')
        .select('id,tipo,registrata_at,created_at,luogo,modalita,stato_verifica')
        .eq('dipendente_id', employeeId)
        .order('registrata_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> registerAttendance({
    required String employeeId,
    required String type,
    required LocationSnapshot location,
    required String mode,
    String? worksiteId,
    String? transferReason,
    String? vehicleId,
    String? place,
    String? note,
  }) async {
    await _client.from('timbrature').insert({
      'dipendente_id': employeeId,
      'tipo': type,
      'registrata_at': DateTime.now().toUtc().toIso8601String(),
      'gps_latitudine': location.latitude,
      'gps_longitudine': location.longitude,
      'gps_precisione_metri': location.accuracy,
      'modalita': mode,
      'cantiere_id': worksiteId,
      'trasferta_motivo': _nullIfEmpty(transferReason),
      'mezzo_id': vehicleId,
      'luogo': _nullIfEmpty(place),
      'nota': _nullIfEmpty(note),
    });
  }

  Future<Map<String, dynamic>> loadAttendanceConfiguration() async {
    final values = await Future.wait([
      _client
          .from('configurazione_azienda')
          .select(
            'ragione_sociale,indirizzo,gps_latitudine,gps_longitudine,'
            'raggio_presenza_metri,controllo_gps_presenze',
          )
          .limit(1),
      _client
          .from('cantieri')
          .select(
            'id,nome,indirizzo,gps_latitudine,gps_longitudine,'
            'raggio_presenza_metri,cliente:clienti(ragione_sociale)',
          )
          .eq('attivo', true)
          .order('nome'),
    ]);
    final companyRows = List<Map<String, dynamic>>.from(values[0] as List);
    final worksites = List<Map<String, dynamic>>.from(values[1] as List);
    return {
      'company': companyRows.isEmpty ? null : companyRows.first,
      'worksites': worksites,
    };
  }

  Future<void> registerFuel({
    required String employeeId,
    required String vehicleId,
    required int km,
    required double liters,
    double? amount,
    String? station,
    LocationSnapshot? location,
  }) async {
    await _client.from('rifornimenti').insert({
      'dipendente_id': employeeId,
      'mezzo_id': vehicleId,
      'data_ora': DateTime.now().toUtc().toIso8601String(),
      'km': km,
      'litri': liters,
      'importo': amount,
      'distributore': _nullIfEmpty(station),
      'gps_latitudine': location?.latitude,
      'gps_longitudine': location?.longitude,
    });
  }

  Future<void> reportAnomaly({
    required String employeeId,
    required String type,
    required String title,
    required String description,
    String? vehicleId,
    String? place,
    LocationSnapshot? location,
  }) async {
    await _client.from('anomalie').insert({
      'segnalata_da': employeeId,
      'tipo': type,
      'titolo': title.trim(),
      'descrizione': description.trim(),
      'mezzo_id': vehicleId,
      'luogo': _nullIfEmpty(place),
      'gps_latitudine': location?.latitude,
      'gps_longitudine': location?.longitude,
    });
  }

  Future<List<Map<String, dynamic>>> loadEmployeeDocuments(
    String employeeId,
  ) async {
    final rows = await _client
        .from('dipendente_documenti')
        .select()
        .eq('dipendente_id', employeeId)
        .eq('attivo', true)
        .eq('visibile_dipendente', true)
        .order('data_scadenza');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadCommunications(
    String employeeId,
  ) async {
    final rows = await _client
        .from('comunicazione_destinatari')
        .select(
          'comunicazione_id,letta_at,confermata_at,'
          'comunicazioni(id,titolo,messaggio,priorita,allegato_url,'
          'richiede_conferma,pubblicata_at,scade_at)',
        )
        .eq('dipendente_id', employeeId)
        .order('comunicazione_id', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markCommunication({
    required String employeeId,
    required String communicationId,
    required bool confirm,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('comunicazione_destinatari')
        .update({
          'letta_at': now,
          if (confirm) 'confermata_at': now,
        })
        .eq('dipendente_id', employeeId)
        .eq('comunicazione_id', communicationId);
  }

  Future<Map<String, dynamic>?> loadCompany() async {
    final rows = await _client.from('configurazione_azienda').select().limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> loadContacts() async {
    final rows = await _client
        .from('contatti_azienda')
        .select()
        .eq('attivo', true)
        .order('ordine');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadEmployees() async {
    final rows = await _client
        .from('v_collaboratori_attivi')
        .select('id,nome_cognome')
        .order('nome_cognome');
    return List<Map<String, dynamic>>.from(rows);
  }

  String? _nullIfEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
