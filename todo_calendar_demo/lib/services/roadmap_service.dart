import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RoadmapSubtask {
  const RoadmapSubtask({
    required this.title,
    required this.durationDays,
    required this.summary,
  });

  final String title;
  final int durationDays;
  final String summary;

  Map<String, dynamic> toJson() => {
        'title': title,
        'duration_days': durationDays,
        'summary': summary,
      };

  factory RoadmapSubtask.fromJson(Map<String, dynamic> json) {
    return RoadmapSubtask(
      title: json['title'] as String? ?? '',
      durationDays: json['duration_days'] is int
          ? json['duration_days'] as int
          : int.tryParse(json['duration_days']?.toString() ?? '') ?? 1,
      summary: json['summary'] as String? ?? '',
    );
  }
}

class RoadmapTaskSpec {
  const RoadmapTaskSpec({
    required this.id,
    required this.title,
    required this.summary,
    required this.durationDays,
    required this.dependencies,
    required this.subtasks,
  });

  final String id;
  final String title;
  final String summary;
  final int durationDays;
  final List<String> dependencies;
  final List<RoadmapSubtask> subtasks;
}

class RoadmapTimelineEntry {
  const RoadmapTimelineEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.durationDays,
    required this.dependencies,
    required this.subtasks,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final int durationDays;
  final List<String> dependencies;
  final List<RoadmapSubtask> subtasks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'duration_days': durationDays,
        'dependencies': dependencies,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
      };

  factory RoadmapTimelineEntry.fromJson(Map<String, dynamic> json) {
    final subtasksJson = json['subtasks'] as List<dynamic>? ?? const [];
    return RoadmapTimelineEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      durationDays: json['duration_days'] is int
          ? json['duration_days'] as int
          : int.tryParse(json['duration_days']?.toString() ?? '') ?? 1,
      dependencies: (json['dependencies'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      subtasks: subtasksJson
          .map((e) => RoadmapSubtask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoadmapResult {
  const RoadmapResult({
    required this.goal,
    required this.timeframeUnit,
    required this.startDate,
    required this.timeline,
    required this.summary,
  });

  final String goal;
  final String timeframeUnit;
  final DateTime startDate;
  final List<RoadmapTimelineEntry> timeline;
  final String summary;

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'timeframeUnit': timeframeUnit,
        'startDate': startDate.toIso8601String(),
        'summary': summary,
        'timeline': timeline.map((e) => e.toJson()).toList(),
      };

  factory RoadmapResult.fromJson(Map<String, dynamic> json) {
    final timelineJson = json['timeline'] as List<dynamic>? ?? const [];
    return RoadmapResult(
      goal: json['goal'] as String? ?? '',
      timeframeUnit: json['timeframeUnit'] as String? ?? 'week',
      startDate: DateTime.parse(json['startDate'] as String),
      summary: json['summary'] as String? ?? '',
      timeline: timelineJson
          .map((e) => RoadmapTimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoadmapService {
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';

  static const _requirementsSystemPrompt = '''
당신은 사용자의 요구사항으로부터 실행 가능한 프로젝트 로드맵을 작성하는 비서입니다.

- 무조건 JSON 형식으로만 응답합니다.
- JSON 최상위 키는 goal, timeframe, start_date, tasks 입니다.
- timeframe 키는 {{"unit": "day|week|month", "span": 정수}} 형태로 제공합니다.
- start_date는 YYYY-MM-DD 형식으로 작성합니다. 사용자가 제공하지 않으면 today 파라미터를 사용합니다.
- tasks는 각 항목마다 {{"id", "title", "summary", "duration_days", "dependencies", "subtasks"}} 를 포함합니다.
- subtasks는 각 항목마다 {{"title", "duration_days"}}를 가진 객체 목록이며, 2~4개의 간결한 한국어 표현으로 작성하고 duration_days 합은 상위 작업 duration_days와 일치하도록 만듭니다.
- dependencies는 선행 작업 id 문자열 목록입니다. 없으면 빈 배열을 사용합니다.
- duration_days는 1 이상의 정수입니다.
- 사용자의 요청이 모호하면 가장 합리적인 가정을 명시적으로 JSON에 기록합니다.
''';

  static const _summarySystemPrompt = '''
당신은 프로젝트 매니저입니다. 주어진 로드맵 정보를 사용자 친화적으로 설명하세요.
프로젝트가 언제 시작해 언제 끝나는지, 어떤 주요 단계를 거치는지, 각 단계가 시작되기 위해 무엇이 선행되어야 하는지 순서대로 설명합니다.
각 단계에서 수행할 주요 하위 작업도 짧게 언급하되, 문단 수는 4개 이하로 유지하세요.
''';

  static Future<RoadmapResult> generateRoadmap({
    required String request,
    required String apiKey,
    DateTime? preferredStartDate,
  }) async {
    final requirementsResponse = await _postChat(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': _requirementsSystemPrompt},
        {
          'role': 'system',
          'content': '오늘 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        },
        {'role': 'user', 'content': request.trim()},
      ],
    );

    final parsed = _loadJson(requirementsResponse);
    final timeframeRaw = parsed['timeframe'] ?? {};
    final timeframeUnit = (timeframeRaw['unit']?.toString().toLowerCase() ?? 'week');
    final goal = parsed['goal']?.toString() ?? request.trim();
    final startDate = _parseDate(parsed['start_date']?.toString(), DateTime.now());
    final tasksRaw = parsed['tasks'];
    if (tasksRaw is! List) {
      throw StateError('tasks 항목이 배열이 아닙니다.');
    }

    final tasks = _normaliseTasks(tasksRaw);
    var timeline = _buildSchedule(tasks, startDate);

    if (preferredStartDate != null && timeline.isNotEmpty) {
      timeline = _alignTimeline(timeline, preferredStartDate);
    }

    final effectiveStartDate =
        timeline.isNotEmpty ? timeline.first.start : (preferredStartDate ?? startDate);
    final timelineLines = _buildTimelineLines(timeline);

    final summaryResponse = await _postChat(
      apiKey: apiKey,
      messages: [
        {'role': 'system', 'content': _summarySystemPrompt},
        {
          'role': 'user',
          'content': '최종 목표: $goal\n기간 단위: $timeframeUnit\n기준 날짜: '
              '${DateFormat('yyyy-MM-dd').format(effectiveStartDate)}\n작업 타임라인:\n$timelineLines',
        },
      ],
    );

    final summary = summaryResponse.trim();

    return RoadmapResult(
      goal: goal,
      timeframeUnit: timeframeUnit,
      startDate: effectiveStartDate,
      timeline: timeline,
      summary: summary,
    );
  }

  static Future<String> _postChat({
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'temperature': 0,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('OpenAI 호출 실패: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw StateError('OpenAI 응답에 choices가 없습니다.');
    }
    final content = (choices.first['message'] as Map<String, dynamic>)['content']?.toString();
    if (content == null) {
      throw StateError('OpenAI 응답에 content가 없습니다.');
    }
    return content;
  }

  static Map<String, dynamic> _loadJson(String rawText) {
    final cleaned = _stripJsonMarkdown(rawText);
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } on FormatException catch (err) {
      throw StateError('JSON 파싱 실패: ${err.message}\n원본: ${cleaned.substring(0, cleaned.length.clamp(0, 400))}');
    }
  }

  static String _stripJsonMarkdown(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('```')) {
      final parts = trimmed.split('```');
      for (final part in parts) {
        final candidate = part.trim();
        if (candidate.startsWith('{') && candidate.endsWith('}')) {
          return candidate;
        }
      }
    }
    return trimmed;
  }

  static DateTime _parseDate(String? value, DateTime defaultValue) {
    if (value == null || value.isEmpty) return defaultValue;
    final formats = ['yyyy-MM-dd', 'yyyy.MM.dd', 'yyyy/MM/dd'];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(value);
      } catch (_) {
        continue;
      }
    }
    try {
      return DateTime.parse(value);
    } catch (_) {
      return defaultValue;
    }
  }

  static List<RoadmapTaskSpec> _normaliseTasks(List<dynamic> tasks) {
    final result = <RoadmapTaskSpec>[];
    for (var i = 0; i < tasks.length; i++) {
      final raw = tasks[i];
      if (raw is! Map<String, dynamic>) continue;
      final id = (raw['id']?.toString().isNotEmpty ?? false)
          ? raw['id'].toString()
          : 'T${(i + 1).toString().padLeft(2, '0')}';
      final title = (raw['title']?.toString().isNotEmpty ?? false)
          ? raw['title'].toString()
          : '작업 ${i + 1}';
      final summary = raw['summary']?.toString() ?? title;
      final durationRaw = raw['duration_days'] ?? raw['duration'] ?? 1;
      int duration;
      try {
        duration = int.parse(durationRaw.toString());
      } catch (_) {
        duration = 1;
      }
      duration = duration < 1 ? 1 : duration;

      final dependenciesRaw = raw['dependencies'];
      final dependencies = <String>[];
      if (dependenciesRaw is List) {
        for (final dep in dependenciesRaw) {
          if (dep == null) continue;
          final depStr = dep.toString().trim();
          if (depStr.isNotEmpty) dependencies.add(depStr);
        }
      } else if (dependenciesRaw != null) {
        dependencies.add(dependenciesRaw.toString().trim());
      }

      final subtasks = _normaliseSubtasks(raw['subtasks'], duration);

      result.add(
        RoadmapTaskSpec(
          id: id,
          title: title,
          summary: summary,
          durationDays: duration,
          dependencies: dependencies,
          subtasks: subtasks,
        ),
      );
    }
    return result;
  }

  static List<RoadmapSubtask> _normaliseSubtasks(dynamic raw, int parentDuration) {
    final subtasks = <RoadmapSubtask>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final title = (item['title']?.toString().trim().isNotEmpty ?? false)
              ? item['title'].toString().trim()
              : (item['summary']?.toString().trim() ?? '세부 작업');
          final summary = item['summary']?.toString().trim() ?? title;
          final durationRaw = item['duration_days'] ?? item['duration'] ?? 1;
          int duration;
          try {
            duration = int.parse(durationRaw.toString());
          } catch (_) {
            duration = 1;
          }
          duration = duration < 1 ? 1 : duration;
          subtasks.add(
            RoadmapSubtask(
              title: title.length > 15 ? title.substring(0, 15) : title,
              durationDays: duration,
              summary: summary,
            ),
          );
        } else {
          final title = item.toString().trim();
          if (title.isNotEmpty) {
            subtasks.add(
              RoadmapSubtask(
                title: title.length > 15 ? title.substring(0, 15) : title,
                durationDays: 1,
                summary: title,
              ),
            );
          }
        }
      }
    } else if (raw is Map<String, dynamic>) {
      final title = raw['title']?.toString().trim() ?? '세부 작업';
      final summary = raw['summary']?.toString().trim() ?? title;
      final durationRaw = raw['duration_days'] ?? 1;
      int duration;
      try {
        duration = int.parse(durationRaw.toString());
      } catch (_) {
        duration = 1;
      }
      subtasks.add(
        RoadmapSubtask(
          title: title.length > 15 ? title.substring(0, 15) : title,
          durationDays: duration < 1 ? 1 : duration,
          summary: summary,
        ),
      );
    } else if (raw != null) {
      final title = raw.toString().trim();
      if (title.isNotEmpty) {
        subtasks.add(
          RoadmapSubtask(
            title: title.length > 15 ? title.substring(0, 15) : title,
            durationDays: 1,
            summary: title,
          ),
        );
      }
    }

    if (subtasks.isEmpty) {
      subtasks.add(
        RoadmapSubtask(
          title: '세부 작업',
          durationDays: parentDuration,
          summary: '세부 작업',
        ),
      );
      return subtasks;
    }

    var total = subtasks.fold<int>(0, (sum, sub) => sum + sub.durationDays);
    if (total <= 0) {
      subtasks
        ..clear()
        ..add(
          RoadmapSubtask(
            title: '세부 작업',
            durationDays: parentDuration,
            summary: '세부 작업',
          ),
        );
      return subtasks;
    }

    if (total != parentDuration) {
      final diff = parentDuration - total;
      final last = subtasks.last;
      final adjusted = last.durationDays + diff;
      subtasks[subtasks.length - 1] = RoadmapSubtask(
        title: last.title,
        durationDays: adjusted < 1 ? 1 : adjusted,
        summary: last.summary,
      );
    }

    return subtasks;
  }

  static List<String> _topologicalOrder(List<RoadmapTaskSpec> tasks) {
    final graph = <String, List<String>>{};
    final indegree = <String, int>{};
    final ids = {for (final task in tasks) task.id};

    for (final task in tasks) {
      indegree.putIfAbsent(task.id, () => 0);
      for (final dep in task.dependencies) {
        if (!ids.contains(dep)) continue;
        graph.putIfAbsent(dep, () => []).add(task.id);
        indegree[task.id] = (indegree[task.id] ?? 0) + 1;
      }
    }

    final queue = <String>[
      for (final id in ids)
        if ((indegree[id] ?? 0) == 0) id,
    ];
    final ordering = <String>[];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      ordering.add(current);
      for (final next in graph[current] ?? const []) {
        indegree[next] = (indegree[next] ?? 0) - 1;
        if ((indegree[next] ?? 0) == 0) {
          queue.add(next);
        }
      }
    }

    if (ordering.length != ids.length) {
      throw StateError('선후관계에 순환이 있어 로드맵을 만들 수 없습니다.');
    }

    return ordering;
  }

  static List<RoadmapTimelineEntry> _buildSchedule(
    List<RoadmapTaskSpec> tasks,
    DateTime baseDate,
  ) {
    final order = _topologicalOrder(tasks);
    final taskMap = {for (final task in tasks) task.id: task};
    final completion = <String, Map<String, DateTime>>{};
    final timeline = <RoadmapTimelineEntry>[];
    var cursor = baseDate;

    for (final taskId in order) {
      final task = taskMap[taskId]!;
      final deps = task.dependencies.where(taskMap.containsKey).toList();
      var startDt = cursor;
      if (deps.isNotEmpty) {
        final latestEnd = deps
            .map((dep) => completion[dep]?['end'] ?? baseDate)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        startDt = latestEnd.add(const Duration(days: 1));
      }
      if (startDt.isBefore(cursor)) {
        startDt = cursor;
      }
      final duration = task.durationDays < 1 ? 1 : task.durationDays;
      final endDt = startDt.add(Duration(days: duration - 1));

      completion[taskId] = {'start': startDt, 'end': endDt};
      cursor = endDt.add(const Duration(days: 1));

      timeline.add(
        RoadmapTimelineEntry(
          id: task.id,
          title: task.title,
          start: startDt,
          end: endDt,
          durationDays: duration,
          dependencies: deps,
          subtasks: task.subtasks,
        ),
      );
    }

    return timeline;
  }

  static String _buildTimelineLines(List<RoadmapTimelineEntry> timeline) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (final item in timeline) {
      final deps = item.dependencies.isEmpty
          ? '선행 없음'
          : item.dependencies.join(', ');
      final subtasks = item.subtasks.isEmpty
          ? '세부 작업 없음'
          : item.subtasks
              .map((sub) => '${sub.title}(${sub.durationDays}일)')
              .join('; ');
      buffer.writeln(
        '- ${item.title} (${dateFormat.format(item.start)} ~ ${dateFormat.format(item.end)}, '
        '${item.durationDays}일, 선행: $deps)\n  · 세부: $subtasks',
      );
    }
    return buffer.toString();
  }

  static List<RoadmapTimelineEntry> _alignTimeline(
    List<RoadmapTimelineEntry> timeline,
    DateTime preferredStart,
  ) {
    if (timeline.isEmpty) return timeline;
    final shiftDays = preferredStart.difference(timeline.first.start).inDays;
    if (shiftDays == 0) return timeline;
    return timeline
        .map(
          (entry) => RoadmapTimelineEntry(
            id: entry.id,
            title: entry.title,
            start: entry.start.add(Duration(days: shiftDays)),
            end: entry.end.add(Duration(days: shiftDays)),
            durationDays: entry.durationDays,
            dependencies: entry.dependencies,
            subtasks: entry.subtasks,
          ),
        )
        .toList();
  }
}
