class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
      : super('Email o password non corrette.');
}

class AccountDisabledException extends AppException {
  const AccountDisabledException()
      : super('Questo account è stato disattivato. Contatta l’amministratore.');
}

class ConnectivityException extends AppException {
  const ConnectivityException()
      : super('Connessione assente. Controlla la rete e riprova.');
}

