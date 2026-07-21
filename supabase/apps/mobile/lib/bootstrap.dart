import 'package:arte_in_ferro_rapportini/app/app.dart';
import 'package:arte_in_ferro_rapportini/core/config/app_config.dart';
import 'package:arte_in_ferro_rapportini/core/database/local_database.dart';
import 'package:arte_in_ferro_rapportini/core/gps/location_service.dart';
import 'package:arte_in_ferro_rapportini/core/media/media_service.dart';
import 'package:arte_in_ferro_rapportini/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arte_in_ferro_rapportini/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/data/datasources/rapportini_remote_data_source.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/data/repositories/offline_rapportini_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = AppConfig.fromEnvironment();

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );

    final localDatabase = LocalDatabase();
    await localDatabase.initialize();
    final remoteDataSource = SupabaseAuthRemoteDataSource(
      Supabase.instance.client,
    );
    final authRepository = SupabaseAuthRepository(
      remoteDataSource,
      localDatabase,
    );
    final rapportiniRepository = OfflineRapportiniRepository(
      database: localDatabase,
      remote: RapportiniRemoteDataSource(Supabase.instance.client),
      media: MediaService(),
    );

    runApp(RapportiniApp(
      authRepository: authRepository,
      rapportiniRepository: rapportiniRepository,
      locationService: LocationService(),
    ));
  } on Object catch (error) {
    runApp(BootstrapFailureApp(message: _safeBootstrapMessage(error)));
  }
}

String _safeBootstrapMessage(Object error) {
  if (error is AppConfigurationException) {
    return error.message;
  }

  return 'Impossibile inizializzare l’app. Controlla la configurazione e riprova.';
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Configurazione incompleta',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
