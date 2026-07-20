import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:arte_in_ferro_rapportini/core/errors/auth_error_mapper.dart';
import 'package:arte_in_ferro_rapportini/features/auth/data/models/app_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRemoteDataSource {
  const SupabaseAuthRemoteDataSource(this._client);

  static const _profileColumns =
      'id,nome_cognome,email,ruolo,attivo,data_creazione';

  final SupabaseClient _client;

  Stream<AppUserModel?> watchAuthState() async* {
    yield await getCurrentUser();

    await for (final authState in _client.auth.onAuthStateChange) {
      try {
        final session = authState.session;
        if (session == null) {
          yield null;
          continue;
        }

        yield await _loadActiveProfile(session.user.id);
      } on Object catch (error) {
        throw AuthErrorMapper.map(error);
      }
    }
  }

  Future<AppUserModel?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return null;
    }

    try {
      return await _loadActiveProfile(session.user.id);
    } on Object catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  Future<AppUserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;

      if (user == null) {
        throw const InvalidCredentialsException();
      }

      return await _loadActiveProfile(user.id);
    } on Object catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Object catch (error) {
      throw AuthErrorMapper.map(error);
    }
  }

  Future<AppUserModel> _loadActiveProfile(String userId) async {
    final json = await _client
        .from('utenti')
        .select(_profileColumns)
        .eq('id', userId)
        .single();
    final profile = AppUserModel.fromJson(json);

    if (!profile.isActive) {
      await _client.auth.signOut();
      throw const AccountDisabledException();
    }

    return profile;
  }
}
