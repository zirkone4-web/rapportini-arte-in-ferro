import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/repositories/rapportini_repository.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/cubit/rapportini_cubit.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/cubit/rapportini_state.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/pages/rapportino_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class RapportiniPage extends StatelessWidget {
  const RapportiniPage({
    required this.user,
    this.openNewOnStart = false,
    this.initialReportId,
    super.key,
  });

  final AppUser user;
  final bool openNewOnStart;
  final String? initialReportId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RapportiniCubit(
        repository: context.read<RapportiniRepository>(),
        dipendenteId: user.id,
      )..load(),
      child: _RapportiniView(
        user: user,
        openNewOnStart: openNewOnStart,
        initialReportId: initialReportId,
      ),
    );
  }
}

class _RapportiniView extends StatefulWidget {
  const _RapportiniView({
    required this.user,
    required this.openNewOnStart,
    this.initialReportId,
  });

  final AppUser user;
  final bool openNewOnStart;
  final String? initialReportId;

  @override
  State<_RapportiniView> createState() => _RapportiniViewState();
}

class _RapportiniViewState extends State<_RapportiniView> {
  StatoRapportino? _filter;
  bool _openedInitialForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<RapportiniCubit>().sync();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RapportiniCubit, RapportiniState>(
      listenWhen: (previous, current) =>
          previous.message != current.message ||
          previous.status != current.status,
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message!)));
          context.read<RapportiniCubit>().clearMessage();
        }
        if (widget.openNewOnStart &&
            !_openedInitialForm &&
            state.status == RapportiniStatus.ready) {
          _openedInitialForm = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _openForm());
        }
        if (widget.initialReportId != null &&
            !_openedInitialForm &&
            state.status == RapportiniStatus.ready) {
          final matches = state.rapportini
              .where((item) => item.id == widget.initialReportId)
              .toList(growable: false);
          if (matches.isNotEmpty) {
            _openedInitialForm = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _openForm(matches.first));
          }
        }
      },
      builder: (context, state) {
        final reports = _filter == null
            ? state.rapportini
            : state.rapportini
                .where((item) => item.stato == _filter)
                .toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: const Text('I miei rapportini'),
            actions: [
              if (state.isSyncing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Sincronizza',
                  onPressed: () => context.read<RapportiniCubit>().sync(),
                  icon: const Icon(Icons.sync),
                ),
            ],
          ),
          floatingActionButton: state.clienti.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openForm,
                  icon: const Icon(Icons.add),
                  label: const Text('NUOVO'),
                ),
          body: SafeArea(
            child: switch (state.status) {
              RapportiniStatus.initial || RapportiniStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              RapportiniStatus.failure => _FailureView(
                  message: state.message ?? 'Impossibile caricare i dati.',
                  onRetry: () => context.read<RapportiniCubit>().load(),
                ),
              RapportiniStatus.ready => RefreshIndicator(
                  onRefresh: () => context.read<RapportiniCubit>().sync(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (state.clienti.isEmpty)
                        _OfflineClientsWarning(
                          onRetry: () =>
                              context.read<RapportiniCubit>().load(),
                        ),
                      DropdownButtonFormField<StatoRapportino?>(
                        initialValue: _filter,
                        decoration: const InputDecoration(
                          labelText: 'Filtra per stato',
                          prefixIcon: Icon(Icons.filter_list),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tutti gli stati'),
                          ),
                          ...StatoRapportino.values.map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 16),
                      if (reports.isEmpty)
                        const _EmptyView()
                      else
                        ...reports.map(
                          (report) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReportCard(
                              report: report,
                              onTap: () => (report.stato.editable ||
                                      report.sincronizzazione ==
                                          StatoSincronizzazione.errore)
                                  ? _openForm(report)
                                  : _showDetails(report),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            },
          ),
        );
      },
    );
  }

  Future<void> _openForm([Rapportino? report]) async {
    if (!mounted) return;
    final cubit = context.read<RapportiniCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: RapportinoFormPage(
            user: widget.user,
            rapportino: report,
          ),
        ),
      ),
    );
    if (saved == true && mounted) await cubit.sync();
  }

  Future<void> _showDetails(Rapportino report) async {
    final date = DateFormat('dd/MM/yyyy HH:mm');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              report.clienteNome,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            _DetailRow('Stato', report.stato.label),
            _DetailRow('Intervento', report.tipologia.label),
            _DetailRow('Inizio', date.format(report.dataOraInizio.toLocal())),
            _DetailRow(
              'Fine',
              report.dataOraFine == null
                  ? '—'
                  : date.format(report.dataOraFine!.toLocal()),
            ),
            _DetailRow('Luogo', report.luogo),
            if (report.notePianificazione?.isNotEmpty == true)
              _DetailRow('Note dell’ufficio', report.notePianificazione!),
            _DetailRow('Descrizione', report.descrizione),
            _DetailRow('Esito lavoro', report.esitoLavoro.label),
            if (report.notaLavoroIncompleto?.isNotEmpty == true)
              _DetailRow('Da completare / materiale', report.notaLavoroIncompleto!),
            if (report.notaAmministratore?.isNotEmpty == true)
              _DetailRow('Nota ufficio', report.notaAmministratore!),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final Rapportino report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd/MM/yyyy, HH:mm');
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(report: report),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.clienteNome,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text('${date.format(report.dataOraInizio.toLocal())} · '
                        '${report.oreTotali.toStringAsFixed(2)} h'),
                    const SizedBox(height: 4),
                    Text(
                      report.luogo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (report.pianificato)
                          const Chip(
                            avatar: Icon(Icons.event_available_outlined, size: 17),
                            label: Text('Assegnato dall’ufficio'),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(report.stato.label),
                        ),
                        _SyncChip(status: report.sincronizzazione),
                      ],
                    ),
                    if (report.notePianificazione?.isNotEmpty == true) ...[
                      const SizedBox(height: 7),
                      Text(
                        report.notePianificazione!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (report.erroreSincronizzazione != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        report.erroreSincronizzazione!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                report.stato.editable ||
                        report.sincronizzazione == StatoSincronizzazione.errore
                    ? Icons.edit_outlined
                    : Icons.lock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.report});

  final Rapportino report;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (report.stato) {
      StatoRapportino.bozza => (Icons.edit_note, Colors.blueGrey),
      StatoRapportino.inviato => (Icons.outbox_outlined, Colors.blue),
      StatoRapportino.approvato => (Icons.verified_outlined, Colors.green),
      StatoRapportino.respinto => (Icons.error_outline, Colors.red),
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .12),
      foregroundColor: color,
      child: Icon(icon),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.status});

  final StatoSincronizzazione status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      StatoSincronizzazione.sincronizzato => (Icons.cloud_done, 'Cloud'),
      StatoSincronizzazione.daSincronizzare => (Icons.cloud_upload, 'Da inviare'),
      StatoSincronizzazione.sincronizzazione => (Icons.sync, 'Invio…'),
      StatoSincronizzazione.errore => (Icons.cloud_off, 'Errore'),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(value.isEmpty ? '—' : value),
          ],
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 56),
            SizedBox(height: 12),
            Text('Nessun rapportino per questo filtro.'),
          ],
        ),
      );
}

class _OfflineClientsWarning extends StatelessWidget {
  const _OfflineClientsWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'L’elenco clienti non è ancora disponibile. Collegati a '
                'Internet almeno una volta prima di creare il primo rapportino.',
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('RIPROVA'),
              ),
            ],
          ),
        ),
      );
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('RIPROVA')),
            ],
          ),
        ),
      );
}
