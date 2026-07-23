import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/cliente.dart';
import 'package:arte_in_ferro_rapportini/features/rapportini/domain/entities/rapportino.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'arte_in_ferro_rapportini.db'),
      version: 6,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Database locale non inizializzato');
    }
    return database;
  }

  Future<void> _onCreate(Database database, int version) async {
    await _createProfileTable(database);

    await database.execute('''
      CREATE TABLE clienti (
        id TEXT PRIMARY KEY,
        ragione_sociale TEXT NOT NULL,
        indirizzo TEXT NOT NULL,
        referente TEXT,
        telefono TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE rapportini (
        id TEXT PRIMARY KEY,
        dipendente_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL,
        cliente_nome TEXT NOT NULL,
        luogo TEXT NOT NULL,
        maps_url TEXT,
        rif_appuntamento TEXT,
        mezzo_id TEXT,
        targa_mezzo TEXT,
        km_mezzo INTEGER,
        collaboratori_ids TEXT NOT NULL DEFAULT '[]',
        tipologia TEXT NOT NULL,
        data_ora_inizio TEXT NOT NULL,
        data_ora_fine TEXT,
        descrizione TEXT NOT NULL,
        firma_locale_path TEXT,
        firma_remote_path TEXT,
        gps_latitudine REAL,
        gps_longitudine REAL,
        gps_precisione_metri REAL,
        gps_rilevato_at TEXT,
        stato TEXT NOT NULL,
        nota_amministratore TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        versione_remota INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL,
        sync_error TEXT,
        pianificato INTEGER NOT NULL DEFAULT 0,
        note_pianificazione TEXT,
        esito_lavoro TEXT NOT NULL DEFAULT 'da_eseguire',
        nota_lavoro_incompleto TEXT,
        FOREIGN KEY(cliente_id) REFERENCES clienti(id)
      )
    ''');

    await database.execute('''
      CREATE TABLE rapportino_foto (
        id TEXT PRIMARY KEY,
        rapportino_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        remote_path TEXT,
        sincronizzato INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(rapportino_id) REFERENCES rapportini(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        next_attempt_at TEXT,
        UNIQUE(entity_type, entity_id, operation)
      )
    ''');

    await database.execute(
      'CREATE INDEX idx_rapportini_dipendente_data '
      'ON rapportini(dipendente_id, data_ora_inizio DESC)',
    );
    await database.execute(
      'CREATE INDEX idx_rapportini_sync ON rapportini(sync_status)',
    );
    await database.execute(
      'CREATE INDEX idx_foto_rapportino ON rapportino_foto(rapportino_id)',
    );
  }

  Future<void> _onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createProfileTable(database);
    if (oldVersion < 3) {
      await database.execute('ALTER TABLE rapportini ADD COLUMN targa_mezzo TEXT');
      await database.execute('ALTER TABLE rapportini ADD COLUMN km_mezzo INTEGER');
    }
    if (oldVersion < 4) {
      await database.execute('ALTER TABLE rapportini ADD COLUMN mezzo_id TEXT');
      await database.execute(
        "ALTER TABLE rapportini ADD COLUMN collaboratori_ids TEXT NOT NULL DEFAULT '[]'",
      );
    }
    if (oldVersion < 5) {
      await database.execute(
        'ALTER TABLE rapportini ADD COLUMN pianificato INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE rapportini ADD COLUMN note_pianificazione TEXT',
      );
      await database.execute(
        "ALTER TABLE rapportini ADD COLUMN esito_lavoro TEXT NOT NULL DEFAULT 'da_eseguire'",
      );
      await database.execute(
        'ALTER TABLE rapportini ADD COLUMN nota_lavoro_incompleto TEXT',
      );
    }
    if (oldVersion < 6) {
      await database.execute(
        'ALTER TABLE rapportini ADD COLUMN maps_url TEXT',
      );
    }
  }

  Future<void> _createProfileTable(Database database) {
    return database.execute('''
      CREATE TABLE IF NOT EXISTS app_profile (
        id TEXT PRIMARY KEY,
        nome_cognome TEXT NOT NULL,
        email TEXT NOT NULL,
        ruolo TEXT NOT NULL,
        attivo INTEGER NOT NULL,
        data_creazione TEXT NOT NULL
      )
    ''');
  }

  Future<AppUser?> loadCachedProfile() async {
    final rows = await _db.query('app_profile', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return AppUser(
      id: row['id']! as String,
      nomeCognome: row['nome_cognome']! as String,
      email: row['email']! as String,
      role: AppRole.values.byName(row['ruolo']! as String),
      isActive: (row['attivo'] as int) == 1,
      createdAt: DateTime.parse(row['data_creazione']! as String),
    );
  }

  Future<void> cacheProfile(AppUser user) async {
    await _db.transaction((transaction) async {
      await transaction.delete('app_profile');
      await transaction.insert('app_profile', {
        'id': user.id,
        'nome_cognome': user.nomeCognome,
        'email': user.email,
        'ruolo': user.role.name,
        'attivo': user.isActive ? 1 : 0,
        'data_creazione': user.createdAt.toUtc().toIso8601String(),
      });
    });
  }

  Future<void> clearCachedProfile() => _db.delete('app_profile');

  Future<List<Cliente>> listClienti() async {
    final rows = await _db.query('clienti', orderBy: 'ragione_sociale ASC');
    return rows.map(Cliente.fromLocalMap).toList(growable: false);
  }

  Future<void> replaceClienti(List<Cliente> clienti) async {
    // Un risultato remoto vuoto non deve cancellare la cache in caso di errore
    // o risposta incompleta del servizio.
    if (clienti.isEmpty) return;

    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    await _db.transaction((transaction) async {
      // Prima inserisce i record cloud: in questo modo i nuovi UUID esistono già
      // quando vengono riallineati i rapportini salvati sul telefono.
      for (final cliente in clienti) {
        await transaction.insert(
          'clienti',
          cliente.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final incomingIds = clienti.map((item) => item.id).toSet();
      final incomingByName = <String, Cliente>{
        for (final item in clienti) normalize(item.ragioneSociale): item,
      };
      final reports = await transaction.query(
        'rapportini',
        columns: ['id', 'cliente_id', 'cliente_nome'],
      );

      for (final row in reports) {
        final currentId = row['cliente_id'] as String?;
        if (currentId == null || incomingIds.contains(currentId)) continue;
        final currentName = row['cliente_nome'] as String? ?? '';
        final replacement = incomingByName[normalize(currentName)];
        if (replacement == null) continue;
        await transaction.update(
          'rapportini',
          {
            'cliente_id': replacement.id,
            'cliente_nome': replacement.ragioneSociale,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }

      final placeholders = List.filled(incomingIds.length, '?').join(',');
      await transaction.delete(
        'clienti',
        where: 'id NOT IN ($placeholders) '
            'AND id NOT IN (SELECT cliente_id FROM rapportini)',
        whereArgs: incomingIds.toList(growable: false),
      );
    });
  }

  Future<List<Rapportino>> listRapportini(String dipendenteId) async {
    final rows = await _db.query(
      'rapportini',
      where: 'dipendente_id = ? OR collaboratori_ids LIKE ?',
      whereArgs: [dipendenteId, '%$dipendenteId%'],
      orderBy: 'data_ora_inizio DESC',
    );
    return rows.map(Rapportino.fromLocalMap).toList(growable: false);
  }

  Future<List<Rapportino>> listPendingRapportini(String dipendenteId) async {
    final rows = await _db.query(
      'rapportini',
      where: '(dipendente_id = ? OR collaboratori_ids LIKE ?) AND sync_status != ?',
      whereArgs: [
        dipendenteId,
        '%$dipendenteId%',
        StatoSincronizzazione.sincronizzato.databaseValue,
      ],
      orderBy: 'updated_at ASC',
    );
    return rows.map(Rapportino.fromLocalMap).toList(growable: false);
  }

  Future<Rapportino?> getRapportino(String id) async {
    final rows = await _db.query(
      'rapportini',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Rapportino.fromLocalMap(rows.first);
  }

  Future<void> upsertRapportino(
    Rapportino rapportino, {
    bool enqueue = false,
  }) async {
    await _db.transaction((transaction) async {
      await transaction.insert(
        'rapportini',
        rapportino.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (enqueue) {
        await transaction.insert(
          'sync_queue',
          {
            'entity_type': 'rapportino',
            'entity_id': rapportino.id,
            'operation': 'upsert',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<RapportinoFoto>> listFoto(String rapportinoId) async {
    final rows = await _db.query(
      'rapportino_foto',
      where: 'rapportino_id = ?',
      whereArgs: [rapportinoId],
      orderBy: 'created_at ASC',
    );
    return rows.map(RapportinoFoto.fromLocalMap).toList(growable: false);
  }

  Future<void> upsertFoto(RapportinoFoto foto) async {
    await _db.insert(
      'rapportino_foto',
      foto.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFoto(String id) async {
    await _db.delete('rapportino_foto', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSyncSucceeded(Rapportino rapportino) async {
    await _db.transaction((transaction) async {
      await transaction.insert(
        'rapportini',
        rapportino
            .copyWith(
              sincronizzazione: StatoSincronizzazione.sincronizzato,
              clearSyncError: true,
            )
            .toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.delete(
        'sync_queue',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['rapportino', rapportino.id],
      );
    });
  }

  Future<void> markSyncFailed(String rapportinoId, String error) async {
    await _db.transaction((transaction) async {
      await transaction.update(
        'rapportini',
        {
          'sync_status': StatoSincronizzazione.errore.databaseValue,
          'sync_error': error,
        },
        where: 'id = ?',
        whereArgs: [rapportinoId],
      );
      await transaction.rawUpdate('''
        UPDATE sync_queue
        SET attempts = attempts + 1,
            last_error = ?,
            next_attempt_at = ?
        WHERE entity_type = 'rapportino' AND entity_id = ?
      ''', [
        error,
        DateTime.now()
            .add(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        rapportinoId,
      ]);
    });
  }
}
