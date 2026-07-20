import 'package:arte_in_ferro_rapportini/features/auth/data/models/app_user_model.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUserModel', () {
    test('converte un profilo Supabase valido', () {
      final model = AppUserModel.fromJson({
        'id': '56b55b35-6558-4ea5-963f-e48f9c717b5f',
        'nome_cognome': 'Mario Rossi',
        'email': 'mario.rossi@example.com',
        'ruolo': 'operatore',
        'attivo': true,
        'data_creazione': '2026-07-20T10:00:00.000Z',
      });

      expect(model.id, '56b55b35-6558-4ea5-963f-e48f9c717b5f');
      expect(model.nomeCognome, 'Mario Rossi');
      expect(model.role, AppRole.operatore);
      expect(model.isActive, isTrue);
      expect(model.toEntity().email, 'mario.rossi@example.com');
    });

    test('rifiuta un ruolo sconosciuto', () {
      expect(
        () => AppUserModel.fromJson({
          'id': '56b55b35-6558-4ea5-963f-e48f9c717b5f',
          'nome_cognome': 'Mario Rossi',
          'email': 'mario.rossi@example.com',
          'ruolo': 'super_admin',
          'attivo': true,
          'data_creazione': '2026-07-20T10:00:00.000Z',
        }),
        throwsFormatException,
      );
    });
  });
}

