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
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.firebaseApiKey,
          appId: config.firebaseAppId,
          messagingSenderId: config.firebaseSenderId,
          projectId: config.firebaseProjectId,
        ),
      );
      instance = PushNotificationService._(FirebaseMessaging.instance);
    } on Object {
      // Una configurazione push assente o momentaneamente non disponibile non
      // deve impedire al dipendente di usare presenze e rapportini.
      instance = null;
    }
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get openedMessages => FirebaseMessaging.onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> activateForUser(String employeeId) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token != null) await _register(employeeId, token);
    await _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (value) => _register(employeeId, value),
    );
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
