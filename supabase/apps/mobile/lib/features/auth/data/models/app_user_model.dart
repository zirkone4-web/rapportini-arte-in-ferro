import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';

class AppUserModel {
  const AppUserModel({
    required this.id,
    required this.nomeCognome,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    final role = switch (json['ruolo']) {
      'admin' => AppRole.admin,
      'operatore' => AppRole.operatore,
      final Object? value => throw FormatException('Ruolo non valido: $value'),
    };

    final createdAtValue = json['data_creazione'];
    if (createdAtValue is! String) {
      throw const FormatException('Data creazione profilo non valida');
    }

    return AppUserModel(
      id: json['id'] as String,
      nomeCognome: json['nome_cognome'] as String,
      email: json['email'] as String,
      role: role,
      isActive: json['attivo'] as bool? ?? false,
      createdAt: DateTime.parse(createdAtValue),
    );
  }

  final String id;
  final String nomeCognome;
  final String email;
  final AppRole role;
  final bool isActive;
  final DateTime createdAt;

  AppUser toEntity() {
    return AppUser(
      id: id,
      nomeCognome: nomeCognome,
      email: email,
      role: role,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}

