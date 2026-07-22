class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.firebaseProjectId = '',
    this.firebaseAppId = '',
    this.firebaseApiKey = '',
    this.firebaseSenderId = '',
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://oibibghbgcdjyimkvere.supabase.co',
    );
    const publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: 'sb_publishable_a2pl_IOhqK3c7_gHUBnnmw_MoKaoptI',
    );
    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
    const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

    if (url.isEmpty || publishableKey.isEmpty) {
      throw const AppConfigurationException(
        'Avvia l’app passando SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY '
        'tramite --dart-define.',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const AppConfigurationException(
        'SUPABASE_URL non è un indirizzo valido.',
      );
    }

    return const AppConfig(
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
      firebaseProjectId: firebaseProjectId,
      firebaseAppId: firebaseAppId,
      firebaseApiKey: firebaseApiKey,
      firebaseSenderId: firebaseSenderId,
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String firebaseProjectId;
  final String firebaseAppId;
  final String firebaseApiKey;
  final String firebaseSenderId;
  bool get firebaseEnabled => firebaseProjectId.isNotEmpty &&
      firebaseAppId.isNotEmpty && firebaseApiKey.isNotEmpty &&
      firebaseSenderId.isNotEmpty;
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
