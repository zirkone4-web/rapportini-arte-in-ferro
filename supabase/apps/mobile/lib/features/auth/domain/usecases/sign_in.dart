import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({required String email, required String password}) {
    return _repository.signIn(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}

