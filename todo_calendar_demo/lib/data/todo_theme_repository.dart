import 'package:uuid/uuid.dart';

import '../models/todo_theme.dart';
import 'local_database.dart';

class TodoThemeRepository {
  TodoThemeRepository._();

  static final TodoThemeRepository instance = TodoThemeRepository._();

  static final List<TodoTheme> _defaultThemes = [
    const TodoTheme(id: 'default', name: '기본', colorValue: 0xFF424242),
    const TodoTheme(id: 'work', name: '회사', colorValue: 0xFF1E88E5),
    const TodoTheme(id: 'school', name: '학교', colorValue: 0xFF43A047),
    const TodoTheme(id: 'personal', name: '개인', colorValue: 0xFF8E24AA),
  ];

  final Uuid _uuid = const Uuid();
  List<TodoTheme> _fallbackThemes = List<TodoTheme>.from(_defaultThemes);

  Future<void> ensureDefaults() async {
    if (!TodoDatabase.isSupported) {
      _fallbackThemes = List<TodoTheme>.from(_defaultThemes);
      return;
    }

    final db = await TodoDatabase.instance.database;
    final existingRows = await db.query('todo_themes', columns: ['id']);
    final existingIds = existingRows.map((row) => row['id'] as String).toSet();
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final theme in _defaultThemes) {
      if (!existingIds.contains(theme.id)) {
        batch.insert('todo_themes', {
          'id': theme.id,
          'name': theme.name,
          'color_value': theme.colorValue,
          'created_at': now,
          'updated_at': now,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<TodoTheme>> fetchAll() async {
    if (!TodoDatabase.isSupported) {
      return List<TodoTheme>.from(_fallbackThemes);
    }
    final db = await TodoDatabase.instance.database;
    final rows = await db.query(
      'todo_themes',
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) {
      return List<TodoTheme>.from(_defaultThemes);
    }
    return rows
        .map(
          (row) => TodoTheme(
            id: row['id'] as String,
            name: row['name'] as String,
            colorValue: row['color_value'] as int,
          ),
        )
        .toList();
  }

  Future<TodoTheme> createTheme({required String name, required int colorValue}) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final theme = TodoTheme(id: id, name: name, colorValue: colorValue);

    if (!TodoDatabase.isSupported) {
      _fallbackThemes = List<TodoTheme>.from(_fallbackThemes)..insert(0, theme);
      return theme;
    }

    final db = await TodoDatabase.instance.database;
    await db.insert('todo_themes', {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'created_at': now,
      'updated_at': now,
    });
    return theme;
  }

  List<TodoTheme> get defaultThemes => List<TodoTheme>.from(_defaultThemes);
}
