import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hubfrete/models/location_point.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Serviço de banco de dados local (SQLite) para fila offline de pontos de localização
class LocationDatabaseService {
  static final LocationDatabaseService instance = LocationDatabaseService._();
  static Database? _database;

  static const String _webQueueKey = 'location_queue_v1';

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
      version: 2,
      onCreate: (db, version) async {
        await _createV2Schema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // É uma fila offline: em caso de schema antigo, recria a tabela
          // para evitar crashes por mismatch de colunas.
          await db.execute('DROP TABLE IF EXISTS location_queue');
          await _createV2Schema(db);
        }
      },
    );
  }

  Future<void> _createV2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE location_queue (
        id TEXT PRIMARY KEY,
        motorista_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        precisao REAL,
        velocidade REAL,
        bussola_pos REAL,
        timestamp INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_synced ON location_queue(synced)');
    await db.execute('CREATE INDEX idx_timestamp ON location_queue(timestamp)');
    await db.execute('CREATE INDEX idx_motorista ON location_queue(motorista_id)');
  }

  Future<List<Map<String, dynamic>>> _webReadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_webQueueKey) ?? <String>[];
    final out = <Map<String, dynamic>>[];
    var changed = false;
    for (final s in raw) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(s) as Map);
        // valida campos mínimos
        if (decoded['id'] is! String || decoded['motorista_id'] is! String) {
          changed = true;
          continue;
        }
        out.add(decoded);
      } catch (e) {
        changed = true;
      }
    }
    if (changed) {
      await prefs.setStringList(_webQueueKey, out.map((m) => jsonEncode(m)).toList());
    }
    return out;
  }

  Future<void> _webWriteQueue(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_webQueueKey, items.map((m) => jsonEncode(m)).toList());
  }

  /// Insere um ponto na fila local
  Future<void> insertPoint(LocationPoint point) async {
    if (kIsWeb) {
      final items = await _webReadQueue();
      items.add(point.toJson());
      await _webWriteQueue(items);
      return;
    }

    final db = await database;
    await db.insert('location_queue', point.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Busca pontos não sincronizados (limitado a 50 por vez)
  Future<List<LocationPoint>> getUnsyncedPoints({int limit = 50}) async {
    if (kIsWeb) {
      final items = await _webReadQueue();
      final pending = items.where((m) => (m['synced'] as int? ?? 0) == 0).toList();
      pending.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
      return pending.take(limit).map((json) => LocationPoint.fromJson(json)).toList();
    }

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
    if (kIsWeb) {
      final items = await _webReadQueue();
      final idSet = ids.toSet();
      for (final item in items) {
        if (idSet.contains(item['id'])) item['synced'] = 1;
      }
      await _webWriteQueue(items);
      return;
    }

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
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    if (kIsWeb) {
      final items = await _webReadQueue();
      items.removeWhere((m) => (m['synced'] as int? ?? 0) == 1 && (m['timestamp'] as int) < cutoff);
      await _webWriteQueue(items);
      return;
    }

    final db = await database;
    await db.delete(
      'location_queue',
      where: 'synced = ? AND timestamp < ?',
      whereArgs: [1, cutoff],
    );
  }

  /// Conta pontos não sincronizados
  Future<int> getUnsyncedCount() async {
    if (kIsWeb) {
      final items = await _webReadQueue();
      return items.where((m) => (m['synced'] as int? ?? 0) == 0).length;
    }

    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM location_queue WHERE synced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Limpa toda a fila (uso apenas para testes/debug)
  Future<void> clearAll() async {
    if (kIsWeb) {
      await _webWriteQueue(<Map<String, dynamic>>[]);
      debugPrint('[LocationDB] Fila limpa (web)');
      return;
    }

    final db = await database;
    await db.delete('location_queue');
    debugPrint('[LocationDB] Fila limpa');
  }
}
