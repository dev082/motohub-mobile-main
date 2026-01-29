import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/location_point.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Serviço de banco de dados local (SQLite) para fila offline de pontos de localização
class LocationDatabaseService {
  static final LocationDatabaseService instance = LocationDatabaseService._();
  static Database? _database;

  LocationDatabaseService._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'location_tracking.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_queue (
            id TEXT PRIMARY KEY,
            email_motorista TEXT NOT NULL,
            entrega_id TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            precisao REAL,
            velocidade REAL,
            bussola_pos REAL,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_synced ON location_queue(synced)');
        await db.execute('CREATE INDEX idx_timestamp ON location_queue(timestamp)');
      },
    );
  }

  /// Insere um ponto na fila local
  Future<void> insertPoint(LocationPoint point) async {
    final db = await database;
    await db.insert('location_queue', point.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Busca pontos não sincronizados (limitado a 50 por vez)
  Future<List<LocationPoint>> getUnsyncedPoints({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'location_queue',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return result.map((json) => LocationPoint.fromJson(json)).toList();
  }

  /// Marca pontos como sincronizados
  Future<void> markAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      'location_queue',
      {'synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  /// Remove pontos antigos já sincronizados (manter últimos 7 dias)
  Future<void> cleanOldSyncedPoints() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await db.delete(
      'location_queue',
      where: 'synced = ? AND timestamp < ?',
      whereArgs: [1, cutoff],
    );
  }

  /// Conta pontos não sincronizados
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM location_queue WHERE synced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Limpa toda a fila (uso apenas para testes/debug)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('location_queue');
    debugPrint('[LocationDB] Fila limpa');
  }
}
