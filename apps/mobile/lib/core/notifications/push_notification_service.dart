import 'dart:async';
import 'dart:io';

import 'package:arte_in_ferro_rapportini/core/config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._(this._messaging);

  final FirebaseMessaging _messaging;
  static PushNotificationService? instance;
  StreamSubscription<String>? _refreshSubscription;

  static Future<void> initialize(AppConfig config) async {
    if (!config.firebaseEnabled) return;

    try {
      if (Firebase.apps.isEmpty) {
        final options = Platform.isIOS
            ? FirebaseOptions(
                apiKey: config.firebaseApiKey,
                appId: config.firebaseAppId,
                messagingSenderId: config.firebaseSenderId,
                projectId: config.firebaseProjectId,
                iosBundleId: config.firebaseIosBundleId,
              )
            : FirebaseOptions(
                apiKey: config.firebaseApiKey,
                appId: config.firebaseAppId,
                messagingSenderId: config.firebaseSenderId,
                projectId: config.firebaseProjectId,
              );

        await Firebase.initializeApp(options: options);
      }

      final messaging = FirebaseMessaging.instance;
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      instance = PushNotificationService._(messaging);
    } on Object {
      instance = null;
    }
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> activateForUser(String employeeId) async {
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    if (Platform.isIOS) {
      await _waitForApnsToken();
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _register(employeeId, token);
    }

    await _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (value) => _register(employeeId, value),
    );
  }

  Future<void> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _register(String employeeId, String token) async {
    await Supabase.instance.client.from('dispositivi_push').upsert({
      'dipendente_id': employeeId,
      'token': token,
      'piattaforma': Platform.isIOS ? 'ios' : 'android',
      'nome_dispositivo': Platform.operatingSystem,
      'attivo': true,
      'ultimo_accesso_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }
}
