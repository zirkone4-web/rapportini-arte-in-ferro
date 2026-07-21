import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arte_in_ferro_rapportini/features/auth/presentation/bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthFailurePage extends StatelessWidget {
  const AuthFailurePage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Servizio non disponibile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      context
                          .read<AuthBloc>()
                          .add(const AuthSubscriptionRequested());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('RIPROVA'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

