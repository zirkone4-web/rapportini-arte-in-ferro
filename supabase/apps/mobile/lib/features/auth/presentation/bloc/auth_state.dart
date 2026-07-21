import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:equatable/equatable.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message, this.isSubmitting = false});

  final String? message;
  final bool isSubmitting;

  @override
  List<Object?> get props => [message, isSubmitting];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

