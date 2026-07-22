import 'package:arte_in_ferro_rapportini/features/company/data/company_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailsPage extends StatelessWidget {
  const ClientDetailsPage({required this.clientId, super.key});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheda cliente')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: CompanyService(Supabase.instance.client).loadClient(clientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text(snapshot.hasError ? '${snapshot.error}' : 'Cliente non disponibile'));
          }
          final item = snapshot.data!;
          final phone = '${item['telefono'] ?? ''}'.trim();
          final address = '${item['indirizzo'] ?? ''}'.trim();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${item['ragione_sociale']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Card(child: ListTile(leading: const Icon(Icons.location_on_outlined), title: const Text('Indirizzo'), subtitle: Text(address), trailing: const Icon(Icons.open_in_new), onTap: address.isEmpty ? null : () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'), mode: LaunchMode.externalApplication))),
              Card(child: ListTile(leading: const Icon(Icons.person_outline), title: const Text('Referente'), subtitle: Text('${item['referente'] ?? '—'}'))),
              Card(child: ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('Telefono'), subtitle: Text(phone.isEmpty ? '—' : phone), trailing: phone.isEmpty ? null : const Icon(Icons.call), onTap: phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:$phone')))),
            ],
          );
        },
      ),
    );
  }
}
