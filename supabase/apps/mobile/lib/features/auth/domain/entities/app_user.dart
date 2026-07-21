import 'package:equatable/equatable.dart';

enum AppRole {
  admin,
  operatore;

  bool get isAdmin => this == AppRole.admin;

  String get label => switch (this) {
        AppRole.admin => 'Amministratore',
        AppRole.operatore => 'Operatore',
      };
}

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.nomeCognome,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String nomeCognome;
  final String email;
  final AppRole role;
  final bool isActive;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        nomeCognome,
        email,
        role,
        isActive,
        createdAt,
      ];
}

