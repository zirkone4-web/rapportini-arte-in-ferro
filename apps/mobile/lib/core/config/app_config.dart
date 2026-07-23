import 'dart:io';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.firebaseProjectId = '',
    this.firebaseApiKey = '',
    this.firebaseSenderId = '',
    this.firebaseAndroidAppId = '',
    this.firebaseIosAppId = '',
    this.firebaseIosBundleId = 'it.arteinferrolascari.rapportini',
  });

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('SUPABASE_URL');
    const configuredPublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    final url = configuredUrl.isEmpty
        ? 'https://oibibghbgcdjyimkvere.supabase.co'
        : configuredUrl;
    final publishableKey = configuredPublishableKey.isEmpty
        ? 'sb_publishable_a2pl_IOhqK3c7_gHUBnnmw_MoKaoptI'
        : configuredPublishableKey;

    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const firebaseSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const legacyFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
    const configuredAndroidAppId = String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
    );
    const configuredIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const configuredIosBundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
    );

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const AppConfigurationException(
        'SUPABASE_URL non Ã¨ un indirizzo valido.',
      );
    }

    return AppConfig(
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
      firebaseProjectId: firebaseProjectId,
      firebaseApiKey: firebaseApiKey,
      firebaseSenderId: firebaseSenderId,
      firebaseAndroidAppId: configuredAndroidAppId.isEmpty
          ? legacyFirebaseAppId
          : configuredAndroidAppId,
      firebaseIosAppId:
          configuredIosAppId.isEmpty ? legacyFirebaseAppId : configuredIosAppId,
      firebaseIosBundleId: configuredIosBundleId.isEmpty
          ? 'it.arteinferrolascari.rapportini'
          : configuredIosBundleId,
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseSenderId;
  final String firebaseAndroidAppId;
  final String firebaseIosAppId;
  final String firebaseIosBundleId;

  String get firebaseAppId =>
      Platform.isIOS ? firebaseIosAppId : firebaseAndroidAppId;

  bool get firebaseEnabled =>
      firebaseProjectId.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseSenderId.isNotEmpty;
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
