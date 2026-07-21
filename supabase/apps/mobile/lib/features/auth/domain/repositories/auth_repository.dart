import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchAuthState();

  Future<AppUser?> getCurrentUser();

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();
}

