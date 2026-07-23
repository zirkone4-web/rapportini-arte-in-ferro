import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static const currentVersion = '0.7.2';

  Future<void> check(BuildContext context) async {
    try {
      final row = await Supabase.instance.client
          .from('configurazione_app')
          .select()
          .eq('piattaforma', 'android')
          .single();
      final latest = '${row['versione_corrente']}';
      if (_compare(latest, currentVersion) <= 0 || !context.mounted) return;

      final mandatory = row['aggiornamento_obbligatorio'] == true ||
          _compare('${row['versione_minima']}', currentVersion) > 0;
      final update = await showDialog<bool>(
        context: context,
        barrierDismissible: !mandatory,
        builder: (dialogContext) => PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            title: const Text('Aggiornamento disponibile'),
            content: Text(
              '${row['messaggio'] ?? 'È disponibile una nuova versione.'}'
              '\n\nVersione $latest',
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('PIÙ TARDI'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('AGGIORNA DAL PLAY STORE'),
              ),
            ],
          ),
        ),
      );
      if (update == true) {
        final uri = Uri.tryParse('${row['store_url']}');
        if (uri != null && uri.hasScheme) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } on Object {
      // Un controllo aggiornamenti non deve impedire l'accesso al lavoro.
    }
  }

  int _compare(String left, String right) {
    final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    for (var index = 0; index < 3; index++) {
      final difference =
          (index < a.length ? a[index] : 0) -
          (index < b.length ? b[index] : 0);
      if (difference != 0) return difference;
    }
    return 0;
  }
}
