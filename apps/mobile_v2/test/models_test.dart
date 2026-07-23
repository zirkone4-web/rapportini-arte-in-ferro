import 'package:arte_in_ferro_mobile_v2/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profilo utente', () {
    final user = AppUser.fromMap({
      'id': '1',
      'nome_cognome': 'Mario Rossi',
      'email': 'mario@example.com',
      'ruolo': 'operatore',
      'attivo': true,
    });

    expect(user.name, 'Mario Rossi');
    expect(user.active, isTrue);
  });
}
