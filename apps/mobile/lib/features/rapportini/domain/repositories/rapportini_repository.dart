import 'dart:typed_data';

import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.offline,
  });

  final int synced;
  final int failed;
  final bool offline;
}

abstract interface class RapportiniRepository {
  Future<List<Cliente>> loadClienti({bool refresh = true});

  Future<List<Rapportino>> loadRapportini(String dipendenteId);

  Future<List<RapportinoFoto>> loadFoto(String rapportinoId);

  Future<void> saveRapportino(
    Rapportino report,
    List<RapportinoFoto> foto,
  );

  Future<String?> capturePhoto(String rapportinoId);

  Future<String> saveSignature(String rapportinoId, Uint8List bytes);

  Future<SyncResult> sync(String dipendenteId);
}

