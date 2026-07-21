class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
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
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
