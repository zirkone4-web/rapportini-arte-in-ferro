import 'dart:typed_data';

import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/repositories/rapportini_repository.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/presentation/cubit/rapportini_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RapportiniCubit extends Cubit<RapportiniState> {
  RapportiniCubit({
    required RapportiniRepository repository,
    required String dipendenteId,
  })  : _repository = repository,
        _dipendenteId = dipendenteId,
        super(const RapportiniState());

  final RapportiniRepository _repository;
  final String _dipendenteId;

  Future<void> load({bool refreshClienti = true}) async {
    emit(state.copyWith(
      status: state.status == RapportiniStatus.initial
          ? RapportiniStatus.loading
          : state.status,
      clearMessage: true,
    ));
    try {
      final clienti = await _repository.loadClienti(refresh: refreshClienti);
      final rapportini = await _repository.loadRapportini(_dipendenteId);
      emit(state.copyWith(
        status: RapportiniStatus.ready,
        clienti: clienti,
        rapportini: rapportini,
        clearMessage: true,
      ));
    } on Object catch (error) {
      emit(state.copyWith(
        status: RapportiniStatus.failure,
        message: _safeMessage(error),
      ));
    }
  }

  Future<void> save(
    Rapportino rapportino,
    List<RapportinoFoto> foto,
  ) async {
    await _repository.saveRapportino(rapportino, foto);
    await load(refreshClienti: false);
  }

  Future<Cliente> createCliente(Cliente cliente) async {
    final created = await _repository.createCliente(cliente);
    final clienti = await _repository.loadClienti(refresh: false);
    emit(state.copyWith(clienti: clienti, clearMessage: true));
    return created;
  }

  Future<void> sync() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true, clearMessage: true));
    try {
      final result = await _repository.sync(_dipendenteId);
      await load(refreshClienti: false);
      final message = result.offline
          ? 'Sei offline: i dati restano al sicuro sul dispositivo.'
          : result.failed > 0
              ? '${result.synced} sincronizzati, ${result.failed} da riprovare.'
              : result.synced > 0
                  ? '${result.synced} rapportini sincronizzati.'
                  : 'Dati aggiornati.';
      emit(state.copyWith(isSyncing: false, message: message));
    } on Object catch (error) {
      emit(state.copyWith(
        isSyncing: false,
        message: _safeMessage(error),
      ));
    }
  }

  Future<List<RapportinoFoto>> loadFoto(String rapportinoId) {
    return _repository.loadFoto(rapportinoId);
  }

  Future<String?> capturePhoto(String rapportinoId) {
    return _repository.capturePhoto(rapportinoId);
  }

  Future<String> saveSignature(String rapportinoId, Uint8List bytes) {
    return _repository.saveSignature(rapportinoId, bytes);
  }

  void clearMessage() => emit(state.copyWith(clearMessage: true));

  String _safeMessage(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.length > 240 ? '${text.substring(0, 240)}…' : text;
  }
}
