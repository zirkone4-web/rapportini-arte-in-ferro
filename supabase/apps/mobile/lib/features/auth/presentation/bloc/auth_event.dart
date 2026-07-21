import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

final class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];

  // Evita che la password venga inclusa nei log di debug di Equatable/Bloc.
  @override
  bool get stringify => false;
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
