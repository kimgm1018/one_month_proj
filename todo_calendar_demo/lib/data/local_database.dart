import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class TodoDatabase {
  TodoDatabase._();

  static final TodoDatabase instance = TodoDatabase._();
  static Directory? _overrideDirectory;
  static bool _testMode = false;

  Database? _db;
  bool _isAvailable = true;

  static bool get isSupported => instance._isAvailable;

  static void overrideDirectory(Directory? directory) {
    _overrideDirectory = directory;
  }

  static void setTestMode(bool enabled) {
    _testMode = enabled;
  }

  static bool get isTestMode => _testMode;

  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    if (_db != null || !_isAvailable) return;

    if (kIsWeb) {
      _isAvailable = false;
      return;
    }

    try {
      final Directory dir =
          _overrideDirectory ?? await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final String path = p.join(dir.path, 'ordoo.db');

      _db = await openDatabase(
        path,
        version: 2,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await db.execute('''
CREATE TABLE todos (
  id TEXT PRIMARY KEY,
  series_id TEXT NOT NULL,
  date INTEGER NOT NULL,
  title TEXT NOT NULL,
  theme_id TEXT NOT NULL,
  memo TEXT,
  start_time_minutes INTEGER,
  end_time_minutes INTEGER,
  notify INTEGER NOT NULL,
  is_series_start INTEGER NOT NULL,
  is_series_end INTEGER NOT NULL,
  is_done INTEGER NOT NULL,
  source_session_id TEXT,
  source_task_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
          await db.execute('CREATE INDEX idx_todos_date ON todos(date);');
          await db.execute('''
CREATE TABLE todo_themes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
          await db.execute('''
CREATE TABLE roadmap_sessions (
  id TEXT PRIMARY KEY,
  user_request TEXT NOT NULL,
  goal TEXT,
  timeframe_unit TEXT,
  preferred_start_date INTEGER,
  summary TEXT,
  roadmap_json TEXT,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
          await db.execute('''
CREATE TABLE roadmap_tasks (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  timeline_entry_id TEXT,
  title TEXT NOT NULL,
  start_date INTEGER,
  end_date INTEGER,
  duration_days INTEGER,
  dependencies TEXT,
  order_index INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(session_id) REFERENCES roadmap_sessions(id) ON DELETE CASCADE
);
''');
          await db.execute('''
CREATE TABLE roadmap_subtasks (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  duration_days INTEGER,
  order_index INTEGER NOT NULL,
  FOREIGN KEY(task_id) REFERENCES roadmap_tasks(id) ON DELETE CASCADE
);
''');
          await db.execute('''
CREATE TABLE roadmap_chat_logs (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  role TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(session_id) REFERENCES roadmap_sessions(id) ON DELETE CASCADE
);
''');
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                "ALTER TABLE todos ADD COLUMN theme_id TEXT NOT NULL DEFAULT 'default'");
            await db.execute('''
CREATE TABLE IF NOT EXISTS todo_themes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');
            await db.execute(
                "ALTER TABLE roadmap_sessions ADD COLUMN roadmap_json TEXT");
          }
        },
      );
    } on MissingPluginException {
      _isAvailable = false;
    } on UnimplementedError {
      _isAvailable = false;
    } on PlatformException {
      _isAvailable = false;
    }
  }

  Future<Database> get database async {
    await init();
    if (!_isAvailable || _db == null) {
      throw StateError('Local database is not available on this platform.');
    }
    return _db!;
  }

  Future<void> close() async {
    if (_db == null) return;
    await _db!.close();
    _db = null;
  }
}
