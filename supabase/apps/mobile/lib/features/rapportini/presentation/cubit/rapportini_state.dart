import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:equatable/equatable.dart';

enum RapportiniStatus { initial, loading, ready, failure }

class RapportiniState extends Equatable {
  const RapportiniState({
    this.status = RapportiniStatus.initial,
    this.rapportini = const [],
    this.clienti = const [],
    this.isSyncing = false,
    this.message,
  });

  final RapportiniStatus status;
  final List<Rapportino> rapportini;
  final List<Cliente> clienti;
  final bool isSyncing;
  final String? message;

  RapportiniState copyWith({
    RapportiniStatus? status,
    List<Rapportino>? rapportini,
    List<Cliente>? clienti,
    bool? isSyncing,
    String? message,
    bool clearMessage = false,
  }) {
    return RapportiniState(
      status: status ?? this.status,
      rapportini: rapportini ?? this.rapportini,
      clienti: clienti ?? this.clienti,
      isSyncing: isSyncing ?? this.isSyncing,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, rapportini, clienti, isSyncing, message];
}
