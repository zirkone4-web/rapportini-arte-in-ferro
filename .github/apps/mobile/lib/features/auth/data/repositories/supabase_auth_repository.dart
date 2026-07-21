import 'package:arte_in_ferro_rapportini/core/database/local_database.dart';
import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:arte_in_ferro_rapportini/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._remoteDataSource, this._database);

  final SupabaseAuthRemoteDataSource _remoteDataSource;
  final LocalDatabase _database;

  @override
  Future<AppUser?> getCurrentUser() async {
    try {
      final user = (await _remoteDataSource.getCurrentUser())?.toEntity();
      if (user == null) {
        await _database.clearCachedProfile();
      } else {
        await _database.cacheProfile(user);
      }
      return user;
    } on AccountDisabledException {
      await _database.clearCachedProfile();
      rethrow;
    } on Object {
      return _database.loadCachedProfile();
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final model = await _remoteDataSource.signIn(
      email: email,
      password: password,
    );
    final user = model.toEntity();
    await _database.cacheProfile(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
    await _database.clearCachedProfile();
  }

  @override
  Stream<AppUser?> watchAuthState() async* {
    try {
      await for (final model in _remoteDataSource.watchAuthState()) {
        final user = model?.toEntity();
        if (user == null) {
          await _database.clearCachedProfile();
        } else {
          await _database.cacheProfile(user);
        }
        yield user;
      }
    } on AccountDisabledException {
      await _database.clearCachedProfile();
      rethrow;
    } on Object {
      final cached = await _database.loadCachedProfile();
      if (cached == null) rethrow;
      yield cached;
    }
  }
}
