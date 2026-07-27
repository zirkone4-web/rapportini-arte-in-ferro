import 'dart:async';
import 'dart:io';

import 'package:arte_in_ferro_rapportini/core/config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) return;
}

class PushNotificationService {
  PushNotificationService._(this._messaging);
  final FirebaseMessaging _messaging;
  static PushNotificationService? instance;
  StreamSubscription<String>? _refreshSubscription;
  String? lastError;

  static Future<void> initialize(AppConfig config) async {
    if (!config.firebaseEnabled) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.firebaseApiKey,
          appId: config.firebaseAppId,
          messagingSenderId: config.firebaseSenderId,
          projectId: config.firebaseProjectId,
        ),
      );
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      instance = PushNotificationService._(FirebaseMessaging.instance);
    } on Object catch (error) {
      // Una configurazione push assente o momentaneamente non disponibile non
      // deve impedire al dipendente di usare presenze e rapportini.
      instance = null;
      // Rimane disponibile nei log di diagnostica senza bloccare l'app.
      // ignore: avoid_print
      print('Firebase non inizializzato: $error');
    }
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get openedMessages => FirebaseMessaging.onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> activateForUser(String employeeId) async {
    lastError = null;
    await _messaging.setAutoInitEnabled(true);
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      lastError = 'Notifiche disattivate nelle impostazioni del telefono.';
      throw StateError(lastError!);
    }
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      lastError = 'Il telefono non ha ricevuto il token Firebase.';
      throw StateError(lastError!);
    }
    await _register(employeeId, token);
    await _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (value) => _register(employeeId, value),
    );
  }

  Future<void> _register(String employeeId, String token) async {
    try {
      await Supabase.instance.client.from('dispositivi_push').upsert({
        'dipendente_id': employeeId,
        'token': token,
        'piattaforma': Platform.isIOS ? 'ios' : 'android',
        'nome_dispositivo': Platform.operatingSystem,
        'attivo': true,
        'ultimo_accesso_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      lastError = null;
    } on Object catch (error) {
      lastError = 'Registrazione notifiche non riuscita: $error';
      rethrow;
    }
  }
}
