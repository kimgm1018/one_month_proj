import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../services/roadmap_service.dart';
import 'local_database.dart';

class RoadmapSaveResult {
  RoadmapSaveResult({
    required this.sessionId,
    required this.taskIdMap,
  });

  final String sessionId;
  final Map<String, String> taskIdMap;
}

class RoadmapSession {
  const RoadmapSession({
    required this.id,
    required this.userRequest,
    required this.summary,
    required this.createdAt,
    this.goal,
    this.preferredStartDate,
    this.result,
  });

  final String id;
  final String userRequest;
  final String summary;
  final DateTime createdAt;
  final String? goal;
  final DateTime? preferredStartDate;
  final RoadmapResult? result;
}

class RoadmapChatMessage {
  const RoadmapChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String role;
  final String message;
  final DateTime createdAt;
}

class RoadmapRepository {
  RoadmapRepository._();

  static final RoadmapRepository instance = RoadmapRepository._();
  final Uuid _uuid = const Uuid();

  Future<RoadmapSaveResult> saveGeneration({
    required String userRequest,
    required RoadmapResult result,
    required DateTime requestedAt,
    DateTime? preferredStartDate,
  }) async {
    if (!TodoDatabase.isSupported) {
      return RoadmapSaveResult(sessionId: '', taskIdMap: const {});
    }
    final db = await TodoDatabase.instance.database;
    final sessionId = _uuid.v4();
    final now = requestedAt.millisecondsSinceEpoch;
    final preferredMillis = preferredStartDate?.millisecondsSinceEpoch;

    final batch = db.batch();
    batch.insert('roadmap_sessions', {
      'id': sessionId,
      'user_request': userRequest,
      'goal': result.goal,
      'timeframe_unit': result.timeframeUnit,
      'preferred_start_date': preferredMillis,
      'summary': result.summary,
      'roadmap_json': jsonEncode(result.toJson()),
      'status': 'completed',
      'created_at': now,
      'updated_at': now,
    });

    batch.insert('roadmap_chat_logs', {
      'id': _uuid.v4(),
      'session_id': sessionId,
      'role': 'user',
      'message': userRequest,
      'created_at': now,
    });

    batch.insert('roadmap_chat_logs', {
      'id': _uuid.v4(),
      'session_id': sessionId,
      'role': 'assistant',
      'message': result.summary,
      'created_at': now,
    });

    final taskIdMap = <String, String>{};
    for (var index = 0; index < result.timeline.length; index++) {
      final entry = result.timeline[index];
      final taskId = _uuid.v4();
      taskIdMap[entry.id] = taskId;
      batch.insert('roadmap_tasks', {
        'id': taskId,
        'session_id': sessionId,
        'timeline_entry_id': entry.id,
        'title': entry.title,
        'start_date': entry.start.millisecondsSinceEpoch,
        'end_date': entry.end.millisecondsSinceEpoch,
        'duration_days': entry.durationDays,
        'dependencies': jsonEncode(entry.dependencies),
        'order_index': index,
        'created_at': now,
        'updated_at': now,
      });

      for (var subIndex = 0; subIndex < entry.subtasks.length; subIndex++) {
        final sub = entry.subtasks[subIndex];
        batch.insert('roadmap_subtasks', {
          'id': _uuid.v4(),
          'task_id': taskId,
          'title': sub.title,
          'summary': sub.summary,
          'duration_days': sub.durationDays,
          'order_index': subIndex,
        });
      }
    }

    await batch.commit(noResult: true);

    return RoadmapSaveResult(sessionId: sessionId, taskIdMap: taskIdMap);
  }

  Future<List<RoadmapSession>> fetchSessions() async {
    if (!TodoDatabase.isSupported) {
      return const [];
    }
    final db = await TodoDatabase.instance.database;
    final rows = await db.query(
      'roadmap_sessions',
      orderBy: 'created_at DESC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  Future<RoadmapSession?> fetchSession(String sessionId) async {
    if (!TodoDatabase.isSupported) {
      return null;
    }
    final db = await TodoDatabase.instance.database;
    final rows = await db.query(
      'roadmap_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  Future<List<RoadmapChatMessage>> fetchChatLogs(String sessionId) async {
    if (!TodoDatabase.isSupported) {
      return const [];
    }
    final db = await TodoDatabase.instance.database;
    final rows = await db.query(
      'roadmap_chat_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (row) => RoadmapChatMessage(
            id: row['id'] as String,
            sessionId: row['session_id'] as String,
            role: row['role'] as String,
            message: row['message'] as String,
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
          ),
        )
        .toList();
  }

  Future<void> appendChatMessage({
    required String sessionId,
    required String role,
    required String message,
    DateTime? createdAt,
  }) async {
    if (!TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    await db.insert('roadmap_chat_logs', {
      'id': _uuid.v4(),
      'session_id': sessionId,
      'role': role,
      'message': message,
      'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  Future<void> updateSession({
    required String sessionId,
    required RoadmapResult result,
    DateTime? preferredStartDate,
  }) async {
    if (!TodoDatabase.isSupported) return;
    final db = await TodoDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final preferredMillis = preferredStartDate?.millisecondsSinceEpoch;

    // 기존 tasks와 subtasks 삭제
    final taskIds = await db.query(
      'roadmap_tasks',
      columns: ['id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    if (taskIds.isNotEmpty) {
      final taskIdList = taskIds.map((row) => row['id'] as String).toList();
      await db.delete(
        'roadmap_subtasks',
        where: 'task_id IN (${List.filled(taskIdList.length, '?').join(',')})',
        whereArgs: taskIdList,
      );
      await db.delete('roadmap_tasks', where: 'session_id = ?', whereArgs: [sessionId]);
    }

    // 새로운 tasks와 subtasks 추가
    final batch = db.batch();
    final taskIdMap = <String, String>{};
    for (var index = 0; index < result.timeline.length; index++) {
      final entry = result.timeline[index];
      final taskId = _uuid.v4();
      taskIdMap[entry.id] = taskId;
      batch.insert('roadmap_tasks', {
        'id': taskId,
        'session_id': sessionId,
        'timeline_entry_id': entry.id,
        'title': entry.title,
        'start_date': entry.start.millisecondsSinceEpoch,
        'end_date': entry.end.millisecondsSinceEpoch,
        'duration_days': entry.durationDays,
        'dependencies': jsonEncode(entry.dependencies),
        'order_index': index,
        'created_at': now,
        'updated_at': now,
      });

      for (var subIndex = 0; subIndex < entry.subtasks.length; subIndex++) {
        final sub = entry.subtasks[subIndex];
        batch.insert('roadmap_subtasks', {
          'id': _uuid.v4(),
          'task_id': taskId,
          'title': sub.title,
          'summary': sub.summary,
          'duration_days': sub.durationDays,
          'order_index': subIndex,
        });
      }
    }

    // 세션 정보 업데이트
    batch.update(
      'roadmap_sessions',
      {
        'goal': result.goal,
        'timeframe_unit': result.timeframeUnit,
        'preferred_start_date': preferredMillis,
        'summary': result.summary,
        'roadmap_json': jsonEncode(result.toJson()),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    await batch.commit(noResult: true);
  }

  RoadmapSession _sessionFromRow(Map<String, Object?> row) {
    final preferredStart = row['preferred_start_date'] as int?;
    final roadmapJson = row['roadmap_json'] as String?;
    RoadmapResult? result;
    if (roadmapJson != null && roadmapJson.isNotEmpty) {
      try {
        result = RoadmapResult.fromJson(
          jsonDecode(roadmapJson) as Map<String, dynamic>,
        );
      } catch (_) {
        result = null;
      }
    }
    return RoadmapSession(
      id: row['id'] as String,
      userRequest: row['user_request'] as String,
      summary: row['summary'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      goal: row['goal'] as String?,
      preferredStartDate:
          preferredStart != null ? DateTime.fromMillisecondsSinceEpoch(preferredStart) : null,
      result: result,
    );
  }
}
