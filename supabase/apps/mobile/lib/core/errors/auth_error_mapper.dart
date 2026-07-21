import 'dart:async';
import 'dart:io';

import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AuthErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) {
      return error;
    }

    if (error is SocketException || error is TimeoutException) {
      return const ConnectivityException();
    }

    if (error is AuthException) {
      final normalized = error.message.toLowerCase();
      if (normalized.contains('invalid login credentials') ||
          normalized.contains('invalid credentials')) {
        return const InvalidCredentialsException();
      }

      if (normalized.contains('email not confirmed')) {
        return AppException(
          'L’indirizzo email non è ancora stato confermato.',
          cause: error,
        );
      }

      if (normalized.contains('rate limit') ||
          normalized.contains('too many requests')) {
        return AppException(
          'Troppi tentativi. Attendi qualche minuto e riprova.',
          cause: error,
        );
      }

      return AppException(
        'Accesso non riuscito. Riprova tra poco.',
        cause: error,
      );
    }

    if (error is PostgrestException) {
      return AppException(
        'Non riesco a caricare il profilo utente.',
        cause: error,
      );
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('network is unreachable')) {
      return const ConnectivityException();
    }

    return AppException(
      'Si è verificato un errore imprevisto.',
      cause: error,
    );
  }
}
