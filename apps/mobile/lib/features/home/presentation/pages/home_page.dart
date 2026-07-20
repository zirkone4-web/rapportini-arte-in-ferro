import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_event.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/widgets/company_mark.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/pages/rapportini_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.user, super.key});

  final AppUser user;

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
            const SizedBox(height: 28),
            _ActionCard(
              icon: Icons.note_add_outlined,
              title: 'Nuovo rapportino',
              subtitle: 'Orari, attività, foto, posizione e firma cliente',
              badge: 'Offline e GPS',
              onTap: () => _openReports(context, openNew: true),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.history_outlined,
              title: 'I miei rapportini',
              subtitle: 'Bozze, inviati, approvati e respinti',
              badge: 'Sincronizzati',
              onTap: () => _openReports(context),
            ),
            if (user.role.isAdmin) ...[
              const SizedBox(height: 14),
              const _ActionCard(
                icon: Icons.dashboard_outlined,
                title: 'Amministrazione',
                subtitle: 'La gestione completa sarà disponibile su Windows',
                badge: 'Desktop',
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
