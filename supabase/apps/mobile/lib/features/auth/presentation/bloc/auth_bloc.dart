import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/sign_in.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/sign_out.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/usecases/watch_auth_state.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_event.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SignIn signIn,
    required SignOut signOut,
    required WatchAuthState watchAuthState,
  })  : _signIn = signIn,
        _signOut = signOut,
        _watchAuthState = watchAuthState,
        super(const AuthInitial()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final SignIn _signIn;
  final SignOut _signOut;
  final WatchAuthState _watchAuthState;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    await emit.forEach(
      _watchAuthState(),
      onData: (user) => user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user),
      onError: (Object error, StackTrace _) =>
          AuthFailure(_messageOf(error)),
    );
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthUnauthenticated(isSubmitting: true));

    try {
      final user = await _signIn(
        email: event.email,
        password: event.password,
      );
      emit(AuthAuthenticated(user));
    } on Object catch (error) {
      emit(AuthUnauthenticated(message: _messageOf(error)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      await _signOut();
      emit(const AuthUnauthenticated());
    } on Object catch (error) {
      emit(AuthFailure(_messageOf(error)));
    }
  }

  String _messageOf(Object error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Si è verificato un errore imprevisto.';
  }
}
