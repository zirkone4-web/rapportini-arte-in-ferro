import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rapportino', () {
    final start = DateTime.utc(2026, 7, 20, 8);
    final end = DateTime.utc(2026, 7, 20, 12, 30);

    Rapportino buildReport() => Rapportino(
          id: '11111111-1111-4111-8111-111111111111',
          dipendenteId: '22222222-2222-4222-8222-222222222222',
          clienteId: '33333333-3333-4333-8333-333333333333',
          clienteNome: 'Cliente Demo',
          luogo: 'Cantiere Palermo',
          tipologia: TipoIntervento.montaggioPosa,
          dataOraInizio: start,
          dataOraFine: end,
          descrizione: 'Montaggio ringhiera',
          stato: StatoRapportino.inviato,
          createdAt: start,
          updatedAt: end,
          gpsLatitudine: 38.1157,
          gpsLongitudine: 13.3615,
        );

    test('calcola le ore totali con frazioni', () {
      expect(buildReport().oreTotali, 4.5);
    });

    test('mantiene i dati nel round-trip SQLite', () {
      final original = buildReport();
      final restored = Rapportino.fromLocalMap(original.toLocalMap());

      expect(restored.id, original.id);
      expect(restored.tipologia, TipoIntervento.montaggioPosa);
      expect(restored.oreTotali, 4.5);
      expect(restored.gpsLatitudine, 38.1157);
      expect(restored.sincronizzazione, StatoSincronizzazione.daSincronizzare);
    });

    test('produce il payload Supabase senza campi solo locali', () {
      final payload = buildReport().toRemoteMap(
        remoteState: StatoRapportino.bozza,
      );

      expect(payload['stato'], 'bozza');
      expect(payload['tipologia_intervento'], 'montaggio_posa');
      expect(payload.containsKey('cliente_nome'), isFalse);
      expect(payload.containsKey('sync_status'), isFalse);
    });
  });
}
