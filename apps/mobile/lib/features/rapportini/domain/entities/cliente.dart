import 'package:equatable/equatable.dart';

class Cliente extends Equatable {
  const Cliente({
    required this.id,
    required this.ragioneSociale,
    required this.indirizzo,
    this.referente,
    this.telefono,
  });

  factory Cliente.fromRemoteJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as String,
      ragioneSociale: json['ragione_sociale'] as String,
      indirizzo: json['indirizzo'] as String? ?? '',
      referente: json['referente'] as String?,
      telefono: json['telefono'] as String?,
    );
  }

  factory Cliente.fromLocalMap(Map<String, Object?> map) {
    return Cliente(
      id: map['id']! as String,
      ragioneSociale: map['ragione_sociale']! as String,
      indirizzo: map['indirizzo'] as String? ?? '',
      referente: map['referente'] as String?,
      telefono: map['telefono'] as String?,
    );
  }

  final String id;
  final String ragioneSociale;
  final String indirizzo;
  final String? referente;
  final String? telefono;

  Map<String, Object?> toLocalMap() => {
        'id': id,
        'ragione_sociale': ragioneSociale,
        'indirizzo': indirizzo,
        'referente': referente,
        'telefono': telefono,
      };

  @override
  List<Object?> get props => [id, ragioneSociale, indirizzo, referente, telefono];
}

