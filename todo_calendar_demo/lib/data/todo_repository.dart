import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';
import 'local_database.dart';

class TodoRepository {
  TodoRepository._();

  static final TodoRepository instance = TodoRepository._();

  Future<List<TodoItem>> fetchAll() async {
    if (!TodoDatabase.isSupported) {
      return const <TodoItem>[];
    }
    final db = await TodoDatabase.instance.database;
    final rows = await db.query(
      'todos',
      orderBy: 'date ASC, start_time_minutes ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(TodoItem.fromDb).toList();
  }

  Future<void> seedTodosIfEmpty(List<TodoItem> items) async {
    if (items.isEmpty || !TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    final countResult = await db.rawQuery('SELECT COUNT(*) AS count FROM todos');
    final count = (countResult.first['count'] as int?) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('todos', item.toDb(createdAt: now, updatedAt: now));
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertTodos(List<TodoItem> items) async {
    if (items.isEmpty || !TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'todos',
        item.toDb(createdAt: now, updatedAt: now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceSeries(String seriesId, List<TodoItem> items) async {
    if (!TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('todos', where: 'series_id = ?', whereArgs: [seriesId]);
      if (items.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in items) {
        await txn.insert(
          'todos',
          item.toDb(createdAt: now, updatedAt: now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteSeries(String seriesId) async {
    if (!TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    await db.delete('todos', where: 'series_id = ?', whereArgs: [seriesId]);
  }

  Future<void> updateTodoFields(List<Map<String, Object?>> updates) async {
    if (updates.isEmpty || !TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final update in updates) {
      final id = update['id'] as String?;
      if (id == null) continue;
      final values = Map<String, Object?>.from(update)
        ..remove('id')
        ..['updated_at'] = now;
      if (values.isEmpty) continue;
      batch.update('todos', values, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> reassignTheme(String fromId, String toId) async {
    if (!TodoDatabase.isSupported || fromId == toId) return;
    final db = await TodoDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'todos',
      {
        'theme_id': toId,
        'updated_at': now,
      },
      where: 'theme_id = ?',
      whereArgs: [fromId],
    );
  }
}
