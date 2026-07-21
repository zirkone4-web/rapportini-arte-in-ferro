import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  AdminService(this._client);

  final SupabaseClient _client;

  String get _adminId =>
      _client.auth.currentUser?.id ?? (throw StateError('Sessione scaduta.'));

  Future<List<Map<String, dynamic>>> loadAttendanceEvents() async {
    final rows = await _client
        .from('v_timbrature_amministrazione')
        .select()
        .order('registrata_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadReports() async {
    final rows = await _client
        .from('rapportini')
        .select(
          'id,luogo,data_ora_inizio,data_ora_fine,ore_totali,descrizione,'
          'stato,nota_amministratore,'
          'dipendente:utenti!rapportini_dipendente_id_fkey(nome_cognome),'
          'cliente:clienti!rapportini_cliente_id_fkey(ragione_sociale)',
        )
        .order('data_ora_inizio', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadDailyAttendance() async {
    final rows = await _client
        .from('v_presenze_giornaliere')
        .select()
        .order('giorno', ascending: false)
        .order('nome_cognome')
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadEmployees() async {
    final rows = await _client
        .from('utenti')
        .select(
          'id,nome_cognome,email,ruolo,attivo,'
          'dipendente_profili(telefono,mansione,reparto,data_assunzione,data_cessazione)',
        )
        .order('nome_cognome');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadClients() async {
    final rows = await _client
        .from('clienti')
        .select(
          'id,ragione_sociale,indirizzo,referente,telefono,attivo,created_at,updated_at',
        )
        .order('ragione_sociale');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadWorksites() async {
    final rows = await _client
        .from('cantieri')
        .select(
          'id,cliente_id,nome,indirizzo,gps_latitudine,gps_longitudine,'
          'raggio_presenza_metri,attivo,note,cliente:clienti(ragione_sociale)',
        )
        .order('nome');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> loadCompanySettings() async {
    final rows = await _client
        .from('configurazione_azienda')
        .select(
          'ragione_sociale,indirizzo,gps_latitudine,gps_longitudine,'
          'raggio_presenza_metri,controllo_gps_presenze',
        )
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> updateAttendanceTime({
    required String id,
    required DateTime dateTime,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('timbrature').update({
      'registrata_at': dateTime.toUtc().toIso8601String(),
      'modificata_da': _adminId,
      'motivo_modifica': reason.trim(),
    }).eq('id', id);
  }

  Future<void> forceAttendance({
    required String employeeId,
    required String type,
    required DateTime dateTime,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('timbrature').insert({
      'dipendente_id': employeeId,
      'tipo': type,
      'registrata_at': dateTime.toUtc().toIso8601String(),
      'gps_latitudine': null,
      'gps_longitudine': null,
      'modalita': 'sede',
      'stato_verifica': 'valida',
      'forzata_da_amministratore': true,
      'luogo': 'Registrazione amministrativa',
      'modificata_da': _adminId,
      'motivo_modifica': reason.trim(),
    });
  }

  Future<void> reviewAttendance({
    required String id,
    required bool approved,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('timbrature').update({
      'stato_verifica': approved ? 'valida' : 'rifiutata',
      'autorizzata_da': _adminId,
      'autorizzata_at': DateTime.now().toUtc().toIso8601String(),
      'modificata_da': _adminId,
      'motivo_modifica': reason.trim(),
    }).eq('id', id);
  }

  Future<void> authorizeHours({
    required String employeeId,
    required DateTime day,
    required String status,
    required double? authorizedHours,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('presenze_revisioni').upsert({
      'dipendente_id': employeeId,
      'giorno': _dateOnly(day),
      'stato': status,
      'ore_autorizzate': authorizedHours,
      'nota_amministratore': reason.trim(),
      'motivo_modifica': reason.trim(),
      'autorizzata_da': _adminId,
      'autorizzata_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'dipendente_id,giorno');
  }

  Future<void> reviewReport({
    required String id,
    required String status,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('rapportini').update({
      'stato': status,
      'nota_amministratore': reason.trim(),
      'motivo_modifica': reason.trim(),
    }).eq('id', id);
  }

  Future<void> saveEmployee({
    required String id,
    required String fullName,
    required String role,
    required bool active,
    required String? phone,
    required String? job,
    required String? department,
    required DateTime? hireDate,
    required DateTime? endDate,
    required String reason,
  }) async {
    _requireReason(reason);
    if (fullName.trim().length < 3) {
      throw StateError('Inserisci nome e cognome.');
    }
    await _client.functions.invoke(
      'gestione-dipendenti',
      body: {'action': 'set_active', 'id': id, 'attivo': active},
    );
    await _client.from('utenti').update({
      'nome_cognome': fullName.trim(),
      'ruolo': role,
      'attivo': active,
      'motivo_modifica': reason.trim(),
    }).eq('id', id);
    await _client.from('dipendente_profili').upsert({
      'dipendente_id': id,
      'telefono': _emptyToNull(phone),
      'mansione': _emptyToNull(job),
      'reparto': _emptyToNull(department),
      'data_assunzione': hireDate == null ? null : _dateOnly(hireDate),
      'data_cessazione': endDate == null ? null : _dateOnly(endDate),
      'motivo_modifica': reason.trim(),
    });
  }

  Future<void> saveClient({
    String? id,
    required String name,
    required String address,
    required String? contact,
    required String? phone,
    required bool active,
    required String reason,
  }) async {
    _requireReason(reason);
    if (name.trim().length < 2 || address.trim().length < 2) {
      throw StateError('Inserisci ragione sociale e indirizzo.');
    }
    final body = {
      'ragione_sociale': name.trim(),
      'indirizzo': address.trim(),
      'referente': _emptyToNull(contact),
      'telefono': _emptyToNull(phone),
      'attivo': active,
      'motivo_modifica': reason.trim(),
    };
    if (id == null) {
      await _client.from('clienti').insert(body);
    } else {
      await _client.from('clienti').update(body).eq('id', id);
    }
  }

  Future<void> saveWorksite({
    String? id,
    required String clientId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int radius,
    required bool active,
    required String? notes,
    required String reason,
  }) async {
    _requireReason(reason);
    if (name.trim().length < 2 || address.trim().length < 2) {
      throw StateError('Inserisci nome e indirizzo del cantiere.');
    }
    final body = {
      'cliente_id': clientId,
      'nome': name.trim(),
      'indirizzo': address.trim(),
      'gps_latitudine': latitude,
      'gps_longitudine': longitude,
      'raggio_presenza_metri': radius,
      'attivo': active,
      'note': _emptyToNull(notes),
      'motivo_modifica': reason.trim(),
    };
    if (id == null) {
      await _client.from('cantieri').insert(body);
    } else {
      await _client.from('cantieri').update(body).eq('id', id);
    }
  }

  Future<void> saveCompanyGeofence({
    required double latitude,
    required double longitude,
    required int radius,
    required bool enabled,
    required String reason,
  }) async {
    _requireReason(reason);
    await _client.from('configurazione_azienda').update({
      'gps_latitudine': latitude,
      'gps_longitudine': longitude,
      'raggio_presenza_metri': radius,
      'controllo_gps_presenze': enabled,
      'motivo_modifica': reason.trim(),
    }).eq('id', true);
  }

  void _requireReason(String value) {
    if (value.trim().length < 3) {
      throw StateError('La motivazione è obbligatoria (almeno 3 caratteri).');
    }
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
