import 'package:supabase_flutter/supabase_flutter.dart';

class MaterialDraftItem {
  const MaterialDraftItem({
    required this.description,
    required this.quantity,
    required this.unit,
    this.notes,
  });

  final String description;
  final double quantity;
  final String unit;
  final String? notes;
}

class MaterialService {
  MaterialService(this._client);
  final SupabaseClient _client;

  Future<void> createRequest({
    required String employeeId,
    required String category,
    required List<MaterialDraftItem> items,
    String? reportId,
    String? notes,
  }) async {
    final header = await _client
        .from('richieste_materiale')
        .insert({
          'dipendente_id': employeeId,
          'rapportino_id': reportId,
          'categoria': category,
          'note': _nullIfEmpty(notes),
        })
        .select('id')
        .single();
    await _client.from('richiesta_materiale_righe').insert(
          items
              .map((item) => {
                    'richiesta_id': header['id'],
                    'descrizione': item.description.trim(),
                    'quantita': item.quantity,
                    'unita': item.unit.trim(),
                    'note': _nullIfEmpty(item.notes),
                  })
              .toList(growable: false),
        );
  }

  Future<List<Map<String, dynamic>>> loadMyRequests(String employeeId) async {
    final rows = await _client
        .from('richieste_materiale')
        .select('id,categoria,stato,note,creata_at,richiesta_materiale_righe(descrizione,quantita,unita)')
        .eq('dipendente_id', employeeId)
        .order('creata_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  String? _nullIfEmpty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
