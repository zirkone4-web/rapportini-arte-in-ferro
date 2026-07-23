import 'package:arte_in_ferro_rapportini/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa la configurazione Supabase di produzione se i define sono assenti', () {
    final config = AppConfig.fromEnvironment();

    expect(
      config.supabaseUrl,
      'https://oibibghbgcdjyimkvere.supabase.co',
    );
    expect(config.supabasePublishableKey, isNotEmpty);
  });
}
