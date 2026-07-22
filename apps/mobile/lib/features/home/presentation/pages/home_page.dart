import 'dart:async';

import 'package:arte_in_ferro_rapportini/core/notifications/push_notification_service.dart';
import 'package:arte_in_ferro_rapportini/core/updates/app_update_service.dart';
import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_event.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/widgets/company_mark.dart';
import 'package:arte_in_ferro_rapportini/features/admin/presentation/admin_dashboard_page.dart';
import 'package:arte_in_ferro_rapportini/features/company/presentation/company_pages.dart';
import 'package:arte_in_ferro_rapportini/features/company/presentation/client_details_page.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/pages/rapportini_page.dart';
import 'package:arte_in_ferro_rapportini/features/materials/presentation/material_request_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.user, super.key});

  final AppUser user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<RemoteMessage>? _notificationSubscription;
  StreamSubscription<RemoteMessage>? _openedNotificationSubscription;

  AppUser get user => widget.user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final push = PushNotificationService.instance;
      if (push != null) {
        unawaited(push.activateForUser(user.id).catchError((_) {}));
        _notificationSubscription = push.foregroundMessages.listen(
          (message) {
            if (!mounted) return;
            final title = message.notification?.title ?? 'Nuova comunicazione';
            final body = message.notification?.body ??
                'Apri Comunicazioni per leggere il nuovo messaggio.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title\n$body'),
                action: SnackBarAction(
                  label: 'APRI',
                  onPressed: () => _push(
                    context,
                    CommunicationsPage(user: user),
                  ),
                ),
              ),
            );
          },
        );
        _openedNotificationSubscription = push.openedMessages.listen(
          _openNotification,
        );
        final initialMessage = await push.getInitialMessage();
        if (initialMessage != null && mounted) {
          await _openNotification(initialMessage);
        }
      }
      await AppUpdateService().check(context);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _openedNotificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openNotification(RemoteMessage message) async {
    if (!mounted) return;
    final type = message.data['type'];
    final clientId = message.data['client_id'];
    final reportId = message.data['report_id'];
    if (type == 'cliente' && clientId != null && clientId.isNotEmpty) {
      await _push(context, ClientDetailsPage(clientId: clientId));
      return;
    }
    if (type == 'rapportino' && reportId != null && reportId.isNotEmpty) {
      await _push(
        context,
        RapportiniPage(user: user, initialReportId: reportId),
      );
      return;
    }
    await _push(context, CommunicationsPage(user: user));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CompanyMark(compact: true),
        actions: [
          IconButton(
            tooltip: 'Esci',
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Ciao, ${_firstName(user.nomeCognome)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  user.role.isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.badge_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(user.role.label),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Servizi aziendali',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth >= 700 ? 1.45 : 1.02,
                  children: [
                    _MenuTile(
                      icon: Icons.fingerprint,
                      title: 'Presenze',
                      subtitle: 'Entrata e uscita',
                      color: const Color(0xFF2563EB),
                      onTap: () => _push(
                        context,
                        AttendancePage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.assignment_outlined,
                      title: 'Rapportini',
                      subtitle: 'Cantieri e squadre',
                      color: const Color(0xFFD86A2E),
                      onTap: () => _openReports(context),
                    ),
                    _MenuTile(
                      icon: Icons.local_gas_station_outlined,
                      title: 'Carburante',
                      subtitle: 'Mezzo e ricevuta',
                      color: const Color(0xFF059669),
                      onTap: () => _push(
                        context,
                        FuelPage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.report_problem_outlined,
                      title: 'Anomalie',
                      subtitle: 'Segnala un problema',
                      color: const Color(0xFFDC2626),
                      onTap: () => _push(
                        context,
                        AnomalyPage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.badge_outlined,
                      title: 'I miei documenti',
                      subtitle: 'Corsi e patentini',
                      color: const Color(0xFF7C3AED),
                      onTap: () => _push(
                        context,
                        EmployeeDocumentsPage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Comunicazioni',
                      subtitle: 'Avvisi aziendali',
                      color: const Color(0xFFCA8A04),
                      onTap: () => _push(
                        context,
                        CommunicationsPage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.inventory_2_outlined,
                      title: 'Materiali',
                      subtitle: 'Richiedi all’ufficio',
                      color: const Color(0xFF0F766E),
                      onTap: () => _push(
                        context,
                        MaterialRequestPage(user: user),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.factory_outlined,
                      title: 'Azienda',
                      subtitle: 'Informazioni utili',
                      color: const Color(0xFF334155),
                      onTap: () => _push(
                        context,
                        const CompanyInfoPage(),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.contact_phone_outlined,
                      title: 'Contatti',
                      subtitle: 'Uffici ed emergenze',
                      color: const Color(0xFF0F766E),
                      onTap: () => _push(
                        context,
                        const ContactsPage(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.note_add_outlined,
              title: 'Nuovo rapportino',
              subtitle: 'Crea rapidamente un nuovo rapporto di cantiere',
              badge: 'Offline e GPS',
              onTap: () => _openReports(context, openNew: true),
            ),
            if (user.role.isAdmin) ...[
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.dashboard_outlined,
                title: 'Amministrazione',
                subtitle: 'Presenze, ore, dipendenti, clienti e cantieri',
                badge: 'Accesso admin',
                onTap: () => _push(context, const AdminDashboardPage()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  Future<void> _openReports(
    BuildContext context, {
    bool openNew = false,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RapportiniPage(
          user: user,
          openNewOnStart: openNew,
        ),
      ),
    );
  }

  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uscire dall’app?'),
        content: const Text(
          'Per rientrare dovrai inserire nuovamente email e password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ESCI'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, color: color),
                ),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(badge),
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
