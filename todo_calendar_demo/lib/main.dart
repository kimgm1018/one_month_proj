import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import 'data/local_database.dart';
import 'data/roadmap_repository.dart';
import 'data/todo_repository.dart';
import 'data/todo_theme_repository.dart';
import 'models/todo_item.dart';
import 'models/todo_theme.dart';
import 'services/notification_service.dart';
import 'services/roadmap_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  await TodoDatabase.instance.init();
  await NotificationService.instance.initialize();
  runApp(const TodoCalendarApp());
}

class TodoCalendarApp extends StatefulWidget {
  const TodoCalendarApp({super.key});

  @override
  State<TodoCalendarApp> createState() => _TodoCalendarAppState();
}

class _TodoCalendarAppState extends State<TodoCalendarApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showSplash = true;

  void _handleThemeChanged(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _handleSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData(brightness: Brightness.light);
    final scheme = base.colorScheme.copyWith(
      primary: Colors.black,
      secondary: Colors.black87,
      surface: const Color(0xFFF5F5F7),
      onSurface: Colors.black,
      outline: Colors.black26,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 0,
      ),
      cardColor: const Color(0xFFF5F5F7),
      dividerColor: Colors.black12,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: Colors.black26,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData(brightness: Brightness.dark);
    final scheme = base.colorScheme.copyWith(
      primary: Colors.white,
      secondary: Colors.white70,
      surface: const Color(0xFF111111),
      onSurface: Colors.white,
      outline: Colors.white24,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: CircleBorder(),
        elevation: 0,
      ),
      cardColor: const Color(0xFF111111),
      dividerColor: Colors.white12,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF111111),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        dragHandleColor: Colors.white24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ordoo',
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ko'),
        Locale('ko', 'KR'),
      ],
      home: _showSplash
          ? SplashScreen(
              onAnimationComplete: _handleSplashComplete,
            )
          : TodoHomePage(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeChanged: _handleThemeChanged,
            ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onAnimationComplete,
  });

  final VoidCallback onAnimationComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 1.5초 후 메인 화면으로 전환
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Ordoo',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
        ),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final Map<DateTime, List<TodoItem>> _todos = {};
  final Uuid _uuid = const Uuid();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _isCalendarExpanded = false;
  bool _notificationsEnabled = false;
  Duration _notificationLeadTime = const Duration(hours: 1);
  bool _isLoading = true;
  bool _useDatabase = false;
  List<TodoTheme> _themes = const [];
  Map<String, TodoTheme> _themeMap = const {};
  String _defaultThemeId = 'default';
  List<RoadmapSession> _roadmapSessions = [];
  final Map<String, List<RoadmapChatMessage>> _memoryChatLogs = {};

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    try {
      if (TodoDatabase.isTestMode) {
        final themes = TodoThemeRepository.instance.defaultThemes;
        final themeMap = {for (final theme in themes) theme.id: theme};
        final defaultTheme = themes.first;
        final today = DateUtils.dateOnly(DateTime.now());
        final seededItems = _buildSeedTodos(today, defaultTheme.id);
        if (!mounted) return;
        setState(() {
          _themes = themes;
          _themeMap = themeMap;
          _defaultThemeId = defaultTheme.id;
          _todos.clear();
          for (final item in seededItems) {
            _insertTodoItem(item);
          }
          _isLoading = false;
        });
        return;
      }

      await TodoDatabase.instance.init();
      _useDatabase = TodoDatabase.isSupported && !TodoDatabase.isTestMode;

      await TodoThemeRepository.instance.ensureDefaults();
      var themes = await TodoThemeRepository.instance.fetchAll();
      if (themes.isEmpty) {
        themes = TodoThemeRepository.instance.defaultThemes;
      }
      final defaultTheme = themes.firstWhere(
        (theme) => theme.id == 'default',
        orElse: () => themes.first,
      );
      final themeMap = {
        for (final theme in themes) theme.id: theme,
      };

      final today = DateUtils.dateOnly(DateTime.now());
      final seededItems = _buildSeedTodos(today, defaultTheme.id);

      if (!_useDatabase) {
        if (!mounted) return;
        setState(() {
          _themes = themes;
          _themeMap = themeMap;
          _defaultThemeId = defaultTheme.id;
          _todos.clear();
          for (final item in seededItems) {
            _insertTodoItem(item);
          }
          _isLoading = false;
        });
        return;
      }

      await TodoRepository.instance.seedTodosIfEmpty(seededItems);
      final todos = await TodoRepository.instance.fetchAll();

      final grouped = <DateTime, List<TodoItem>>{};
      for (final todo in todos) {
        final key = DateUtils.dateOnly(todo.date);
        grouped.putIfAbsent(key, () => <TodoItem>[]).add(todo);
      }

      if (!mounted) return;

      setState(() {
        _themes = themes;
        _themeMap = themeMap;
        _defaultThemeId = defaultTheme.id;
        _todos
          ..clear()
          ..addAll(grouped);
        _isLoading = false;
      });

      await _refreshAllNotifications();
      await _loadRoadmapSessions();
    } catch (error, stackTrace) {
      debugPrint('초기화 중 오류 발생: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _todos.clear();
        _isLoading = false;
        _themes = TodoThemeRepository.instance.defaultThemes;
        _themeMap = {
          for (final theme in _themes) theme.id: theme,
        };
        _defaultThemeId = _themes.first.id;
        _useDatabase = false;
      });
    }
  }

  List<TodoItem> _buildSeedTodos(DateTime today, String themeId) {
    final seriesA = _nextSeriesId();
    final seriesB = _nextSeriesId();
    final seriesC = _nextSeriesId();

    return [
      TodoItem(
        id: _nextTodoId(),
        seriesId: seriesA,
        date: today,
        title: 'UI 윤곽 잡기',
        themeId: themeId,
        memo: '와이어프레임과 색감 정리를 위해 스케치',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        notify: _notificationsEnabled,
        isSeriesStart: true,
        isSeriesEnd: true,
      ),
      TodoItem(
        id: _nextTodoId(),
        seriesId: seriesB,
        date: today,
        title: '핵심 기능 정리',
        themeId: themeId,
        memo: 'Todo/Calendar 핵심 플로우 문서화',
        notify: _notificationsEnabled,
        isDone: true,
        isSeriesStart: true,
        isSeriesEnd: true,
      ),
      TodoItem(
        id: _nextTodoId(),
        seriesId: seriesC,
        date: today,
        title: '데이터 구조 초안 작성',
        themeId: themeId,
        notify: _notificationsEnabled,
        isSeriesStart: true,
        isSeriesEnd: true,
      ),
    ];
  }

  List<TodoItem> get _selectedTodos {
    final list = List<TodoItem>.from(_todos[_selectedDay] ?? const <TodoItem>[]);
    list.sort(_todoComparator);
    return list;
  }

  void _toggleCalendarExpansion([bool? expand]) {
    setState(() {
      _isCalendarExpanded = expand ?? !_isCalendarExpanded;
    });
  }

  void _handleDaySelected(
    DateTime selectedDay,
    DateTime focusedDay, {
    bool collapseAfterSelect = false,
  }) {
    setState(() {
      _selectedDay = DateUtils.dateOnly(selectedDay);
      _focusedDay = DateUtils.dateOnly(focusedDay);
      if (collapseAfterSelect) {
        _isCalendarExpanded = false;
      }
    });
  }

  String get _formatLabel =>
      _calendarFormat == CalendarFormat.week ? '1주 보기' : '2주 보기';

  static final List<int> _leadTimeMinuteOptions =
      List<int>.generate(24, (index) => (index + 1) * 5);

  DateTime _clampDate(DateTime date) {
    final min = DateTime.now().subtract(const Duration(days: 365));
    final max = DateTime.now().add(const Duration(days: 365));
    if (date.isBefore(min)) return DateUtils.dateOnly(min);
    if (date.isAfter(max)) return DateUtils.dateOnly(max);
    return DateUtils.dateOnly(date);
  }

  void _shiftDays(int days) {
    final target = _clampDate(_focusedDay.add(Duration(days: days)));
    setState(() {
      _focusedDay = target;
      _selectedDay = target;
    });
  }

  void _shiftWeeks(int direction) {
    final step = _calendarFormat == CalendarFormat.week ? 7 : 14;
    _shiftDays(direction * step);
  }

  static const List<String> _weekdayKorean = [
    '월요일',
    '화요일',
    '수요일',
    '목요일',
    '금요일',
    '토요일',
    '일요일',
  ];

  String _formatKoreanDate(DateTime date) {
    final weekday = _weekdayKorean[date.weekday == DateTime.sunday ? 6 : date.weekday - 1];
    return '${date.month}월 ${date.day}일 $weekday';
  }

  String _formatKoreanMonthYear(DateTime date) => '${date.year}년 ${date.month}월';

  int _todoComparator(TodoItem a, TodoItem b) {
    if (a.isDone != b.isDone) {
      return a.isDone ? 1 : -1;
    }
    final dateCompare = DateUtils.dateOnly(a.date)
        .compareTo(DateUtils.dateOnly(b.date));
    if (dateCompare != 0) return dateCompare;
    final aMinutes = a.startTime?.hourMinuteValue ?? 24 * 60;
    final bMinutes = b.startTime?.hourMinuteValue ?? 24 * 60;
    if (aMinutes != bMinutes) return aMinutes.compareTo(bMinutes);
    return a.title.compareTo(b.title);
  }

  Future<void> _scheduleNotificationsForTodo(TodoItem todo) async {
    if (todo.id.isEmpty) return;
    if (!_notificationsEnabled || todo.isDone || !todo.notify || !todo.hasAnyTime) {
      await NotificationService.instance.cancelTodoReminders(todo.id);
      return;
    }

    final baseDate = DateUtils.dateOnly(todo.date);
    DateTime? startDateTime;
    DateTime? endDateTime;
    if (todo.startTime != null) {
      startDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        todo.startTime!.hour,
        todo.startTime!.minute,
      );
    }
    if (todo.endTime != null) {
      endDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        todo.endTime!.hour,
        todo.endTime!.minute,
      );
    }

    await NotificationService.instance.scheduleTodoReminder(
      todoId: todo.id,
      title: todo.title,
      memo: todo.memo,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      leadTime: _notificationLeadTime,
    );
  }

  void _applyNotificationDefault(bool enabled) {
    final updates = <Map<String, Object?>>[];
    setState(() {
      _todos.updateAll((key, list) {
        return list
            .map((todo) {
              final shouldNotify = enabled && todo.hasAnyTime;
              if (todo.notify == shouldNotify) {
                return todo;
              }
              final updated = todo.copyWith(notify: shouldNotify);
              updates.add({
                'id': updated.id,
                'notify': shouldNotify ? 1 : 0,
              });
              return updated;
            })
            .toList(growable: false);
      });
    });

    if (updates.isNotEmpty) {
      if (_useDatabase) {
        unawaited(TodoRepository.instance.updateTodoFields(updates));
      }
    }
  }

  Future<void> _refreshAllNotifications() async {
    if (!_notificationsEnabled) {
      await NotificationService.instance.cancelAll();
      return;
    }

    for (final list in _todos.values) {
      for (final todo in list) {
        await _scheduleNotificationsForTodo(todo);
      }
    }
  }

  Future<void> _cancelAllNotifications() async {
    await NotificationService.instance.cancelAll();
  }

  Future<int?> _pickLeadTimeMinutes(BuildContext context, int currentMinutes) async {
    final options = _leadTimeMinuteOptions;
    int initialIndex = options.indexOf(currentMinutes);
    if (initialIndex < 0) {
      initialIndex = options.indexWhere((value) => value > currentMinutes);
      if (initialIndex < 0) {
        initialIndex = options.length - 1;
      }
    }
    int tempIndex = initialIndex;
    final controller = FixedExtentScrollController(initialItem: initialIndex);

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                    Text(
                      '알림 시점',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(options[tempIndex]),
                      child: const Text('완료'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    scrollController: controller,
                    magnification: 1.05,
                    squeeze: 1.1,
                    useMagnifier: true,
                    itemExtent: 44,
                    onSelectedItemChanged: (index) => tempIndex = index,
                    children: [
                      for (final minutes in options)
                        Center(child: Text('$minutes분 전에 알림'))
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const int _defaultGroupColor = 0xFF1E88E5;
  static const List<int> _baseGroupColors = [
    0xFFE53935, // Red
    0xFFF57C00, // Orange
    0xFFFDD835, // Yellow
    0xFF43A047, // Green
    0xFF1E88E5, // Blue
    0xFF3949AB, // Indigo
    0xFF8E24AA, // Purple
    0xFF6D4C41, // Brown
  ];

  Future<TodoTheme?> _showGroupEditorDialog({TodoTheme? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final initialColorValue = existing?.colorValue ?? _defaultGroupColor;
    var red = (initialColorValue >> 16) & 0xFF;
    var green = (initialColorValue >> 8) & 0xFF;
    var blue = initialColorValue & 0xFF;
    int? selectedPreset =
        _baseGroupColors.contains(initialColorValue) ? initialColorValue : null;
    Color? initialCustomColor =
        selectedPreset == null ? Color(initialColorValue) : null;
    final customSlotColors = List<Color?>.filled(2, null, growable: false);
    if (initialCustomColor != null) {
      customSlotColors[0] = initialCustomColor;
    }
    int? customSlotIndex =
        initialCustomColor != null ? 0 : null;
    var isCustomSelected = customSlotIndex != null;
    var showCustomPicker = false;
    String? errorText;

    return showDialog<TodoTheme>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentColorValue =
                (0xFF << 24) | (red << 16) | (green << 8) | blue;
            final previewColor = Color(currentColorValue);
            return AlertDialog(
              title: Text(existing == null ? '새 그룹 만들기' : '그룹 수정하기'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '그룹 이름',
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '색상 선택',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      Widget paletteCircle({
                        required bool selected,
                        required VoidCallback onTap,
                        Color? color,
                        bool isPlus = false,
                      }) {
                        final scheme = Theme.of(context).colorScheme;
                        final iconColor = color != null
                            ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                ? Colors.white
                                : Colors.black)
                            : scheme.onSurface;
                        final borderColor = color ??
                            (selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.1));
                        final borderWidth = color != null
                            ? 2.0
                            : (selected ? 2.0 : 1.2);
                        return SizedBox(
                          width: 42,
                          height: 42,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onTap();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isPlus
                                    ? (color ??
                                        (selected
                                            ? scheme.primary.withValues(alpha: 0.08)
                                            : Colors.transparent))
                                    : color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: borderColor,
                                  width: borderWidth,
                                ),
                                boxShadow: selected && !isPlus && color != null
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: isPlus
                                  ? Icon(
                                      Icons.add,
                                      color: iconColor,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }

                      List<Widget> buildRow(List<_PaletteEntry> entries) {
                        return [
                          for (var i = 0; i < entries.length; i++) ...[
                            paletteCircle(
                              selected: entries[i].selected,
                              onTap: entries[i].onTap,
                              color: entries[i].color,
                              isPlus: entries[i].isPlus,
                            ),
                            if (i != entries.length - 1) const SizedBox(width: 10),
                          ]
                        ];
                      }

                      final topRow = <_PaletteEntry>[];
                      final bottomRow = <_PaletteEntry>[];

                      var plusCounter = 0;

                      for (var i = 0; i < 5; i++) {
                        if (i < _baseGroupColors.length) {
                          final colorValue = _baseGroupColors[i];
                          topRow.add(_PaletteEntry(
                            color: Color(colorValue),
                            selected: selectedPreset == colorValue,
                            onTap: () {
                              setDialogState(() {
                                selectedPreset = colorValue;
                                red = (colorValue >> 16) & 0xFF;
                                green = (colorValue >> 8) & 0xFF;
                                blue = colorValue & 0xFF;
                                isCustomSelected = false;
                                showCustomPicker = false;
                                customSlotIndex = null;
                              });
                            },
                          ));
                        } else {
                          final currentPlusIndex = plusCounter++;
                          topRow.add(_PaletteEntry.plus(
                            color: customSlotColors[currentPlusIndex],
                            selected: customSlotIndex == currentPlusIndex && isCustomSelected,
                            onTap: () {
                              setDialogState(() {
                                showCustomPicker = true;
                                selectedPreset = null;
                                isCustomSelected = true;
                                customSlotIndex = currentPlusIndex;
                                final existing = customSlotColors[currentPlusIndex];
                                if (existing != null) {
                                  red = existing.red;
                                  green = existing.green;
                                  blue = existing.blue;
                                }
                              });
                            },
                          ));
                        }
                      }

                      for (var i = 5; i < 10; i++) {
                        if (i < _baseGroupColors.length) {
                          final colorValue = _baseGroupColors[i];
                          bottomRow.add(_PaletteEntry(
                            color: Color(colorValue),
                            selected: selectedPreset == colorValue,
                            onTap: () {
                              setDialogState(() {
                                selectedPreset = colorValue;
                                red = (colorValue >> 16) & 0xFF;
                                green = (colorValue >> 8) & 0xFF;
                                blue = colorValue & 0xFF;
                                isCustomSelected = false;
                                showCustomPicker = false;
                                customSlotIndex = null;
                              });
                            },
                          ));
                        } else {
                          final currentPlusIndex = plusCounter++;
                          bottomRow.add(_PaletteEntry.plus(
                            color: customSlotColors[currentPlusIndex],
                            selected: customSlotIndex == currentPlusIndex && isCustomSelected,
                            onTap: () {
                              setDialogState(() {
                                showCustomPicker = true;
                                selectedPreset = null;
                                isCustomSelected = true;
                                customSlotIndex = currentPlusIndex;
                                final existing = customSlotColors[currentPlusIndex];
                                if (existing != null) {
                                  red = existing.red;
                                  green = existing.green;
                                  blue = existing.blue;
                                }
                              });
                            },
                          ));
                        }
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: buildRow(topRow),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: buildRow(bottomRow),
                          ),
                        ],
                      );
                    },
                  ),
                  if (showCustomPicker) ...[
                    const SizedBox(height: 16),
                      ColorPicker(
                      pickerColor: previewColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          red = color.red;
                          green = color.green;
                          blue = color.blue;
                          selectedPreset = null;
                          customSlotIndex ??= 0;
                          customSlotColors[customSlotIndex!] = color;
                          isCustomSelected = true;
                          showCustomPicker = true;
                        });
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      portraitOnly: true,
                      labelTypes: const [],
                      paletteType: PaletteType.hueWheel,
                      colorPickerWidth: 360,
                      pickerAreaHeightPercent: 0.5,
                    ),
                  ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() {
                        errorText = '그룹 이름을 입력해주세요.';
                      });
                      return;
                    }
                    final colorValue =
                        (0xFF << 24) | (red << 16) | (green << 8) | blue;
                    final result = existing == null
                        ? await TodoThemeRepository.instance
                            .createTheme(name: name, colorValue: colorValue)
                        : await TodoThemeRepository.instance
                            .updateTheme(id: existing.id, name: name, colorValue: colorValue);
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop(result);
                  },
                  child: Text(existing == null ? '추가' : '저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _upsertGroupInState(TodoTheme group) {
    setState(() {
      final updated = List<TodoTheme>.from(_themes);
      final existingIndex = updated.indexWhere((element) => element.id == group.id);
      if (existingIndex >= 0) {
        updated[existingIndex] = group;
      } else {
        updated.insert(0, group);
      }
      _themes = updated;
      _themeMap = {for (final theme in _themes) theme.id: theme};
    });
  }

  void _reassignTodosInMemory(String fromId, String toId) {
    final updated = <DateTime, List<TodoItem>>{};
    for (final entry in _todos.entries) {
      updated[entry.key] = [
        for (final item in entry.value)
          item.themeId == fromId ? item.copyWith(themeId: toId) : item,
      ];
    }
    _todos
      ..clear()
      ..addAll(updated);
  }

  Future<bool> _deleteGroup(TodoTheme group, {required String fallbackId}) async {
    if (group.id == fallbackId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기본 그룹은 삭제할 수 없습니다.')),
      );
      return false;
    }

    if (_useDatabase) {
      await TodoThemeRepository.instance.deleteTheme(group.id);
      await TodoRepository.instance.reassignTheme(group.id, fallbackId);
    } else {
      await TodoThemeRepository.instance.deleteTheme(group.id);
    }

    if (!mounted) return false;

    setState(() {
      _reassignTodosInMemory(group.id, fallbackId);
      _themes = _themes.where((theme) => theme.id != group.id).toList();
      _themeMap = {for (final theme in _themes) theme.id: theme};
    });

    return true;
  }

  Future<String?> _showGroupManager(String activeGroupId) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var groups = List<TodoTheme>.from(_themes);
        var selectedId = activeGroupId;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final maxHeight =
                math.min(MediaQuery.of(context).size.height * 0.7, 120 + groups.length * 72.0);

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '그룹 관리',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.of(sheetContext).pop(selectedId),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '할 일을 묶을 그룹을 만들고 수정하거나 삭제할 수 있습니다.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: maxHeight,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isDefault = group.id == _defaultThemeId;
                          final isSelected = group.id == selectedId;
                          return ListTile(
                            onTap: () {
                              selectedId = group.id;
                              Navigator.of(sheetContext).pop(group.id);
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? group.color.withValues(alpha: 0.6)
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                              ),
                            ),
                            tileColor: isSelected
                                ? group.color.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.surface,
                            leading: CircleAvatar(
                              backgroundColor: group.color,
                              foregroundColor: Colors.white,
                              child: Text(
                                group.name.trim().isEmpty
                                    ? 'G'
                                    : group.name.trim().substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            subtitle: isDefault
                                ? const Text('기본 그룹')
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '그룹 수정',
                                  onPressed: () async {
                                    final updated = await _showGroupEditorDialog(existing: group);
                                    if (updated == null) return;
                                    _upsertGroupInState(updated);
                                    setSheetState(() {
                                      groups = List<TodoTheme>.from(_themes);
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: isDefault ? '기본 그룹은 삭제할 수 없습니다.' : '그룹 삭제',
                                  onPressed: isDefault
                                      ? null
                                      : () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) {
                                              return AlertDialog(
                                                title: const Text('그룹 삭제'),
                                                content: Text(
                                                    '\'${group.name}\' 그룹을 삭제하면 해당 그룹의 할 일은 기본 그룹으로 이동합니다. 계속할까요?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                                    child: const Text('취소'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                                    child: const Text('삭제'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (confirm != true) return;
                                          final deleted =
                                              await _deleteGroup(group, fallbackId: _defaultThemeId);
                                          if (!deleted) return;
                                          setSheetState(() {
                                            groups = List<TodoTheme>.from(_themes);
                                            if (!groups.any((item) => item.id == selectedId)) {
                                              selectedId = _defaultThemeId;
                                            }
                                          });
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('새 그룹 추가'),
                        onPressed: () async {
                          final created = await _showGroupEditorDialog();
                          if (created == null) return;
                          _upsertGroupInState(created);
                          setSheetState(() {
                            groups = List<TodoTheme>.from(_themes);
                            selectedId = created.id;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _createTodo() async {
    if (_isLoading) return;
    final result = await _showTodoForm(initialDate: _selectedDay);
    if (result == null || result.isDeleteRequest) return;

    final newItems = _buildSeriesItems(result, seriesId: _nextSeriesId());
    if (newItems.isEmpty) return;

    if (_useDatabase) {
      await TodoRepository.instance.insertTodos(newItems);
    }

    if (!mounted) return;
    setState(() {
      for (final item in newItems) {
        _insertTodoItem(item);
      }
    });

    for (final item in newItems) {
      unawaited(_scheduleNotificationsForTodo(item));
    }
  }

  Future<void> _editTodo(TodoItem todo) async {
    final series = _seriesItems(todo.seriesId);
    final result = await _showTodoForm(
      initialDate: todo.date,
      existingSeries: series,
    );
    if (result == null) return;

    if (result.isDeleteRequest) {
      await _deleteTodo(todo);
      return;
    }

    final newItems = _buildSeriesItems(result, seriesId: todo.seriesId);
    final doneByDate = {
      for (final item in series)
        DateUtils.dateOnly(item.date): item.isDone,
    };
    final metadataByDate = {
      for (final item in series)
        DateUtils.dateOnly(item.date): item,
    };
    final adjustedItems = newItems
        .map((item) => doneByDate[DateUtils.dateOnly(item.date)] == true
            ? item.copyWith(isDone: true)
            : item)
        .map((item) {
      final original = metadataByDate[DateUtils.dateOnly(item.date)];
      if (original == null) return item;
      return item.copyWith(
        sourceSessionId: original.sourceSessionId,
        sourceTaskId: original.sourceTaskId,
      );
    }).toList(growable: false);

    if (_useDatabase) {
      await TodoRepository.instance.replaceSeries(todo.seriesId, adjustedItems);
    }

    if (!mounted) return;
    setState(() {
      _removeSeries(todo.seriesId);
      for (final item in adjustedItems) {
        _insertTodoItem(item);
      }
    });

    for (final item in series) {
      unawaited(NotificationService.instance.cancelTodoReminders(item.id));
    }
    for (final item in adjustedItems) {
      unawaited(_scheduleNotificationsForTodo(item));
    }
  }

  Future<void> _confirmDelete(TodoItem todo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('선택한 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteTodo(todo);
    }
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final series = _seriesItems(todo.seriesId);
    if (_useDatabase) {
      await TodoRepository.instance.deleteSeries(todo.seriesId);
    }

    if (!mounted) return;
    setState(() {
      _removeSeries(todo.seriesId);
    });

    for (final item in series) {
      unawaited(NotificationService.instance.cancelTodoReminders(item.id));
    }
  }

  List<TodoItem> _buildSeriesItems(
    _TodoFormResult result, {
    String? seriesId,
  }) {
    final id = seriesId ?? _nextSeriesId();
    final dates = _datesInRange(result.startDate, result.endDate);
    final items = <TodoItem>[];
    final hasStartTime = result.startTime != null;
    final hasEndTime = result.endTime != null;
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final isStart = i == 0;
      final isEnd = i == dates.length - 1;
      final assignStartTime = hasStartTime && (!hasEndTime || hasEndTime && (isStart || dates.length == 1));
      final assignEndTime = hasEndTime && (isEnd || dates.length == 1);
      items.add(TodoItem(
        id: _nextTodoId(),
        seriesId: id,
        date: date,
        title: result.title,
        themeId: result.themeId,
        memo: result.memo,
        startTime: assignStartTime ? result.startTime : null,
        endTime: assignEndTime ? result.endTime : null,
        notify: result.notify,
        isSeriesStart: isStart,
        isSeriesEnd: isEnd,
      ));
    }
    return items;
  }

  List<DateTime> _datesInRange(DateTime start, DateTime end) {
    var current = DateUtils.dateOnly(start);
    final last = DateUtils.dateOnly(end);
    final dates = <DateTime>[];
    while (!current.isAfter(last)) {
      dates.add(current);
      current = DateUtils.dateOnly(current.add(const Duration(days: 1)));
    }
    return dates;
  }

  Future<_TodoFormResult?> _showTodoForm({
    required DateTime initialDate,
    List<TodoItem>? existingSeries,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedSeries = existingSeries != null
        ? (List<TodoItem>.from(existingSeries)
          ..sort((a, b) => a.date.compareTo(b.date)))
        : null;

    final initialStartDate = sortedSeries?.first.date ?? initialDate;
    final initialEndDate = sortedSeries?.last.date ?? initialStartDate;
    final initialTitle = sortedSeries?.first.title ?? '';
    final initialMemo = sortedSeries?.first.memo;
    final initialStartTime = sortedSeries
        ?.firstWhere((item) => item.isSeriesStart, orElse: () => sortedSeries.first)
        .startTime;
    final initialEndTime = sortedSeries
        ?.firstWhere((item) => item.isSeriesEnd, orElse: () => sortedSeries.last)
        .endTime;
    final initialNotify = sortedSeries?.first.notify ?? _notificationsEnabled;
    final initialThemeId = sortedSeries?.first.themeId ?? _defaultThemeId;

    final titleController = TextEditingController(text: initialTitle);
    final memoController = TextEditingController(text: initialMemo ?? '');
    DateTime startDate = DateUtils.dateOnly(initialStartDate);
    DateTime endDate = DateUtils.dateOnly(initialEndDate);
    TimeOfDay? startTime = initialStartTime;
    TimeOfDay? endTime = initialEndTime;
    bool notify = initialNotify;
    String selectedThemeId = initialThemeId;

    if (!(startTime != null || endTime != null)) {
      notify = false;
    }

    bool hasTime() => startTime != null || endTime != null;
    final globalOn = _notificationsEnabled;

    void ensureDateOrder({bool keepEnd = false}) {
      if (endDate.isBefore(startDate)) {
        if (keepEnd) {
          startDate = endDate;
        } else {
          endDate = startDate;
        }
      }
    }

    Future<void> pickDate({required bool isStart}) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: isStart ? startDate : endDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      if (isStart) {
        startDate = DateUtils.dateOnly(picked);
        ensureDateOrder();
      } else {
        endDate = DateUtils.dateOnly(picked);
        ensureDateOrder(keepEnd: true);
      }
    }

    Future<void> pickTime({required bool isStart}) async {
      final now = TimeOfDay.now();
      final hadTime = hasTime();
      final initialTime = isStart
          ? startTime ?? now
          : endTime ??
              (startTime != null
                  ? startTime!.replacing(hour: (startTime!.hour + 1) % 24)
                  : now);
      final picked = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) => Theme(
          data: theme.copyWith(
            colorScheme: colorScheme,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        ),
      );
      if (picked == null) return;
      if (isStart) {
        startTime = picked;
        if (startDate == endDate &&
            endTime != null &&
            startTime!.hourMinuteValue > endTime!.hourMinuteValue) {
          endTime = picked.replacing(hour: (picked.hour + 1) % 24);
        }
      } else {
        endTime = picked;
        if (startDate == endDate &&
            startTime != null &&
            startTime!.hourMinuteValue > endTime!.hourMinuteValue) {
          startTime = endTime!.replacing(
            hour: (endTime!.hour - 1).clamp(0, 23),
          );
        }
      }
      if (globalOn && !hadTime && hasTime()) {
        notify = true;
      }
    }

    return showModalBottomSheet<_TodoFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final titleValid = titleController.text.trim().isNotEmpty;
            final canToggleNotification = hasTime();

            if (!_themeMap.containsKey(selectedThemeId) && _themes.isNotEmpty) {
              selectedThemeId = _themes.first.id;
            }

            String notificationSubtitle() {
              if (!canToggleNotification) {
                return '시간을 입력하면 알림을 조절할 수 있습니다.';
              }
              if (globalOn) {
                return notify
                    ? '이 일정의 알림을 켠 상태입니다.'
                    : '이 일정에 대한 알림이 꺼집니다.';
              }
              return notify
                  ? '알림을 받을 수 있도록 설정합니다.'
                  : '이 일정에 대한 알림을 받지 않습니다.';
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sortedSeries == null ? '할 일 추가' : '할 일 수정',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '할 일 (필수)',
                        hintText: '예: 캘린더 연동 검토',
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: memoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '메모 (선택)',
                        hintText: '기억하고 싶은 내용을 적어두세요',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '그룹',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedThemeId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _themes
                          .map(
                            (todoTheme) => DropdownMenuItem<String>(
                              value: todoTheme.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: todoTheme.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(todoTheme.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          selectedThemeId = value;
                        });
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final managed = await _showGroupManager(selectedThemeId);
                          if (managed == null) return;
                          if (!_themeMap.containsKey(managed)) return;
                          setModalState(() {
                            selectedThemeId = managed;
                          });
                        },
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('그룹 관리'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDateTimeSection(
                      context: context,
                      label: '시작',
                      date: startDate,
                      time: startTime,
                      onPickDate: () async {
                        await pickDate(isStart: true);
                        setModalState(() {});
                      },
                      onPickTime: () async {
                        await pickTime(isStart: true);
                        setModalState(() {});
                      },
                      onClearTime: startTime != null
                          ? () {
                              setModalState(() {
                                startTime = null;
                                if (!hasTime()) notify = false;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDateTimeSection(
                      context: context,
                      label: '마감',
                      date: endDate,
                      time: endTime,
                      onPickDate: () async {
                        await pickDate(isStart: false);
                        setModalState(() {});
                      },
                      onPickTime: () async {
                        await pickTime(isStart: false);
                        setModalState(() {});
                      },
                      onClearTime: endTime != null
                          ? () {
                              setModalState(() {
                                endTime = null;
                                if (!hasTime()) notify = false;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '시작/마감 날짜는 필요에 따라 여러 날을 걸쳐 설정할 수 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: canToggleNotification
                          ? (globalOn ? !notify : notify)
                          : false,
                      onChanged: canToggleNotification
                          ? (value) => setModalState(() {
                                notify = globalOn ? !value : value;
                              })
                          : null,
                      title: Text(
                        globalOn ? '이 일정 알림 끄기' : '이 일정 알림 받기',
                      ),
                      subtitle: Text(notificationSubtitle()),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                        Row(
                          children: [
                            if (sortedSeries != null)
                              TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pop(_TodoFormResult.delete()),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                                child: const Text('삭제'),
                              ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: titleValid
                                  ? () {
                                      FocusScope.of(context).unfocus();
                                      Navigator.of(context).pop(
                                        _TodoFormResult(
                                          title: titleController.text.trim(),
                                          memo: memoController.text.trim().isEmpty
                                              ? null
                                              : memoController.text.trim(),
                                          startDate: startDate,
                                          endDate: endDate,
                                          themeId: selectedThemeId,
                                          startTime: startTime,
                                          endTime: endTime,
                                          notify: canToggleNotification
                                              ? notify
                                              : false,
                                        ),
                                      );
                                    }
                                  : null,
                              child: const Text('저장'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateTimeSection({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onPickDate,
    required TimeOfDay? time,
    required VoidCallback onPickTime,
    VoidCallback? onClearTime,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPickDate,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_formatKoreanDate(date)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onPickTime,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(time != null ? _formatTimeOfDay(time) : '시간 없음'),
                ),
              ),
            ),
            if (time != null && onClearTime != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClearTime,
                icon: const Icon(Icons.close, size: 18),
                tooltip: '시간 지우기',
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _toggleTodo(TodoItem item) {
    TodoItem? updated;
    setState(() {
      final key = DateUtils.dateOnly(item.date);
      final list = _todos[key];
      if (list == null) return;
      final index = list.indexWhere((todo) => todo.id == item.id);
      if (index == -1) return;
      final current = list[index];
      final toggled = current.copyWith(isDone: !current.isDone);
      list[index] = toggled;
      updated = toggled;
    });

    if (updated == null) return;
    if (_useDatabase) {
      unawaited(TodoRepository.instance.updateTodoFields([
        {
          'id': updated!.id,
          'is_done': updated!.isDone ? 1 : 0,
        }
      ]));
    }
    if (updated!.isDone) {
      unawaited(NotificationService.instance.cancelTodoReminders(updated!.id));
    } else {
      unawaited(_scheduleNotificationsForTodo(updated!));
    }
  }

  Future<void> _openRoadmapCenter() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RoadmapSessionListSheet(
        sessions: _roadmapSessions,
        useDatabase: _useDatabase,
      ),
    );

    if (!mounted || result == null) return;
    if (result is String && result == 'new') {
      await _openRoadmapChat();
    } else if (result is RoadmapSession) {
      await _openRoadmapChat(session: result);
    }
  }

  Future<void> _openRoadmapChat({RoadmapSession? session}) async {
    List<RoadmapChatMessage> initialMessages = const [];
    if (session != null) {
      if (_useDatabase) {
        initialMessages =
            await RoadmapRepository.instance.fetchChatLogs(session.id);
      } else {
        initialMessages = _memoryChatLogs[session.id] ?? const [];
      }
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => RoadmapChatPage(
          session: session,
          initialMessages: initialMessages,
          useDatabase: _useDatabase,
          defaultStartDate: _selectedDay,
          onSessionChanged: _handleRoadmapSessionUpdated,
          onImport: (result, metadata, {themeId}) =>
              _importRoadmapResult(result, metadata: metadata, themeId: themeId),
          themeMap: _themeMap,
          defaultThemeId: _defaultThemeId,
        ),
      ),
    );
  }

  Future<void> _openRoadmapChatFromTodo(String sessionId) async {
    RoadmapSession? session;
    
    if (_useDatabase) {
      // 데이터베이스에서 세션 불러오기
      session = await RoadmapRepository.instance.fetchSession(sessionId);
    } else {
      // 인메모리 저장소에서 세션 찾기
      try {
        session = _roadmapSessions.firstWhere(
          (s) => s.id == sessionId,
        );
      } catch (e) {
        session = null;
      }
    }

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로드맵 세션을 찾을 수 없습니다.')),
        );
      }
      return;
    }

    await _openRoadmapChat(session: session);
  }

  void _handleRoadmapSessionUpdated(
    RoadmapSession session,
    List<RoadmapChatMessage> messages,
  ) {
    setState(() {
      _roadmapSessions.removeWhere((element) => element.id == session.id);
      _roadmapSessions.insert(0, session);
      if (!_useDatabase) {
        _memoryChatLogs[session.id] = messages;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mediaPadding = MediaQuery.of(context).padding;
    const fabHorizontalPadding = 35.0;
    const compactSpacing = 8.0;
    const defaultSpacing = 12.0;
    final fabBottomPadding =
        mediaPadding.bottom + (mediaPadding.bottom > 0 ? compactSpacing : defaultSpacing);
    final fabLocation = _AdaptiveCenterFloatFabLocation(fabBottomPadding);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ordoo',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '주간/2주 전환',
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.week
                    ? CalendarFormat.twoWeeks
                    : CalendarFormat.week;
              });
            },
            icon: const Icon(Icons.calendar_view_week_outlined),
          ),
          IconButton(
            tooltip: '설정',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButtonAnimator: const _NoOpFabAnimator(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.fromLTRB(
          fabHorizontalPadding,
          0,
          fabHorizontalPadding,
          0,
        ),
        child: Row(
          children: [
            FloatingActionButton(
              heroTag: 'roadmap-fab',
              tooltip: '로드맵 생성',
              backgroundColor: const Color.fromARGB(255, 223, 138, 12),
              foregroundColor: Colors.white,
              onPressed: _isLoading ? null : _openRoadmapCenter,
              child: const Icon(Icons.add),
            ),
            const Spacer(),
            FloatingActionButton(
              heroTag: 'todo-fab',
              tooltip: '할 일 추가',
              onPressed: _isLoading ? null : _createTodo,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isCalendarExpanded
                    ? _buildExpandedCalendarView(context)
                    : Column(
                        key: const ValueKey('collapsed-calendar'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCalendar(context),
                          const SizedBox(height: 20),
                          Text(
                            _sectionTitle,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: _selectedTodos.isEmpty
                                  ? _EmptyState(selectedDay: _selectedDay)
                                  : ListView.separated(
                                      itemCount: _selectedTodos.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 32,
                                        thickness: 0.6,
                                        color: scheme.outline.withValues(alpha: 0.3),
                                      ),
                                      itemBuilder: (context, index) {
                                        final todo = _selectedTodos[index];
                                        return _TodoTile(
                                          item: todo,
                                          theme: _themeMap[todo.themeId],
                                          onToggle: () => _toggleTodo(todo),
                                          onEdit: () => _editTodo(todo),
                                          onDelete: () => _confirmDelete(todo),
                                          onOpenRoadmap: todo.sourceSessionId != null
                                              ? () => _openRoadmapChatFromTodo(todo.sourceSessionId!)
                                              : null,
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
    );
  }

  String get _sectionTitle => _formatKoreanDate(_selectedDay);

  String _nextTodoId() => _uuid.v4();
  String _nextSeriesId() => _uuid.v4();

  void _insertTodoItem(TodoItem todo) {
    final key = DateUtils.dateOnly(todo.date);
    final list = _todos.putIfAbsent(key, () => <TodoItem>[]);
    list.add(todo);
  }

  List<TodoItem> _seriesItems(String seriesId) {
    final items = <TodoItem>[];
    _todos.forEach((_, list) {
      items.addAll(list.where((todo) => todo.seriesId == seriesId));
    });
    return items;
  }

  void _removeSeries(String seriesId) {
    final keys = _todos.keys.toList(growable: false);
    for (final date in keys) {
      final list = _todos[date];
      if (list == null) continue;
      list.removeWhere((todo) => todo.seriesId == seriesId);
      if (list.isEmpty) {
        _todos.remove(date);
      }
    }
  }

  Widget _buildCalendar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => _toggleCalendarExpansion(true),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outline.withValues(alpha: isDark ? 0.4 : 0.2),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                _CalendarArrowButton(
                  icon: Icons.keyboard_double_arrow_left,
                  onPressed: () => _shiftWeeks(-1),
                ),
                const SizedBox(width: 4),
                _CalendarArrowButton(
                  icon: Icons.chevron_left,
                  onPressed: () => _shiftDays(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _formatLabel,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _CalendarArrowButton(
                  icon: Icons.chevron_right,
                  onPressed: () => _shiftDays(1),
                ),
                const SizedBox(width: 4),
                _CalendarArrowButton(
                  icon: Icons.keyboard_double_arrow_right,
                  onPressed: () => _shiftWeeks(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TableCalendar<TodoItem>(
              locale: 'ko_KR',
              focusedDay: _focusedDay,
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onDaySelected: (selectedDay, focusedDay) =>
                  _handleDaySelected(selectedDay, focusedDay),
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = DateUtils.dateOnly(focusedDay)),
              eventLoader: (day) =>
                  _todos[DateUtils.dateOnly(day)] ?? const <TodoItem>[],
              headerStyle: HeaderStyle(
                titleCentered: false,
                formatButtonVisible: false,
                leftChevronVisible: false,
                rightChevronVisible: false,
                titleTextFormatter: (date, locale) => _formatKoreanMonthYear(date),
                titleTextStyle: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ) ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              calendarStyle: CalendarStyle(
                markersAlignment: Alignment.bottomCenter,
                markersMaxCount: 6,
                markersOffset: const PositionedOffset(bottom: 0),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                ),
                selectedDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                selectedTextStyle: TextStyle(color: scheme.onPrimary),
                weekendTextStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                defaultTextStyle: TextStyle(color: scheme.onSurface),
                outsideTextStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
                markerDecoration: const BoxDecoration(),
                todayTextStyle: TextStyle(color: scheme.onSurface),
              ),
              calendarBuilders: CalendarBuilders<TodoItem>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final dots = events.take(6).map((todo) {
                    final themeColor = _themeMap[todo.themeId]?.color ?? scheme.primary;
                    final color = todo.isDone
                        ? themeColor.withValues(alpha: 0.35)
                        : themeColor;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(growable: false);

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: dots,
                      ),
                    ),
                  );
                },
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                weekendStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCalendarView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = _formatKoreanMonthYear(_focusedDay);

    return Column(
      key: const ValueKey('expanded-calendar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '달력 접기',
              onPressed: () => _toggleCalendarExpansion(false),
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48), // balance close button space
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outline.withValues(alpha: isDark ? 0.4 : 0.2),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: TableCalendar<TodoItem>(
              locale: 'ko_KR',
              focusedDay: _focusedDay,
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: '월간 보기',
              },
              shouldFillViewport: true,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) => _handleDaySelected(
                selectedDay,
                focusedDay,
                collapseAfterSelect: true,
              ),
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = DateUtils.dateOnly(focusedDay)),
              eventLoader: (day) =>
                  _todos[DateUtils.dateOnly(day)] ?? const <TodoItem>[],
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: scheme.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface,
                ),
                titleTextFormatter: (date, locale) => _formatKoreanMonthYear(date),
                titleTextStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              calendarStyle: CalendarStyle(
                markersAlignment: Alignment.bottomCenter,
                markersMaxCount: 8,
                markersOffset: const PositionedOffset(bottom: 0),
                todayDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                ),
                selectedDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                selectedTextStyle: TextStyle(color: scheme.onPrimary),
                weekendTextStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                defaultTextStyle: TextStyle(color: scheme.onSurface),
                outsideTextStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.3),
                ),
                markerDecoration: const BoxDecoration(),
                todayTextStyle: TextStyle(color: scheme.onSurface),
              ),
              calendarBuilders: CalendarBuilders<TodoItem>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final dots = events.take(8).map((todo) {
                    final themeColor = _themeMap[todo.themeId]?.color ?? scheme.primary;
                    final color = todo.isDone
                        ? themeColor.withValues(alpha: 0.35)
                        : themeColor;
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(growable: false);

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        runSpacing: 3,
                        children: dots,
                      ),
                    ),
                  );
                },
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                weekendStyle: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _importRoadmapResult(
    RoadmapResult roadmap, {
    RoadmapSaveResult? metadata,
    String? themeId,
  }) async {
    final sessionId = metadata?.sessionId;
    final taskIdMap = metadata?.taskIdMap ?? {
      for (final entry in roadmap.timeline) entry.id: _uuid.v4(),
    };
    final projectThemeId = themeId ?? _defaultThemeId;
    final newTodos = <TodoItem>[];

    for (final entry in roadmap.timeline) {
      final totalSubDays =
          entry.subtasks.fold<int>(0, (sum, sub) => sum + sub.durationDays);
      if (totalSubDays <= 0) {
        continue;
      }
      final seriesId = _nextSeriesId();
      var dayOffset = 0;
      final taskSourceId =
          taskIdMap[entry.id] ?? _uuid.v4();
      final baseDate = DateUtils.dateOnly(entry.start);
      for (final sub in entry.subtasks) {
        for (var i = 0; i < sub.durationDays; i++) {
          dayOffset++;
          final isStart = dayOffset == 1;
          final isEnd = dayOffset == totalSubDays;
          final date = baseDate.add(Duration(days: dayOffset - 1));
          final titleSuffix =
              sub.durationDays > 1 ? ' (${i + 1}/${sub.durationDays})' : '';
          newTodos.add(
            TodoItem(
              id: _nextTodoId(),
              seriesId: seriesId,
              date: date,
              title: '${entry.title} - ${sub.title}$titleSuffix',
              themeId: projectThemeId,
              memo: '로드맵 단계: ${entry.title}\n세부 작업: ${sub.summary}',
              notify: _notificationsEnabled,
              isSeriesStart: isStart,
              isSeriesEnd: isEnd,
              sourceSessionId:
                  (sessionId != null && sessionId.isNotEmpty) ? sessionId : null,
              sourceTaskId: taskSourceId,
            ),
          );
        }
      }
    }

    if (newTodos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추가할 일정이 없습니다.')),
        );
      }
      return;
    }

    if (_useDatabase) {
      await TodoRepository.instance.insertTodos(newTodos);
    }

    if (!mounted) return;
    setState(() {
      for (final todo in newTodos) {
        _insertTodoItem(todo);
      }
    });

    for (final todo in newTodos) {
      unawaited(_scheduleNotificationsForTodo(todo));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('로드맵에서 ${newTodos.length}개의 할 일을 추가했습니다.')),
    );
  }

  Future<void> _loadRoadmapSessions() async {
    if (!_useDatabase) return;
    final sessions = await RoadmapRepository.instance.fetchSessions();
    if (!mounted) return;
    setState(() {
      _roadmapSessions = sessions;
    });
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        var isDark = widget.isDarkMode;
        var notificationsEnabled = _notificationsEnabled;
        var leadMinutes = _notificationLeadTime.inMinutes;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final scheme = Theme.of(context).colorScheme;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '설정',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선호하는 그룹을 선택하세요.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile.adaptive(
                      value: isDark,
                      onChanged: (value) {
                        setModalState(() => isDark = value);
                        widget.onThemeChanged(value);
                      },
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '다크 모드',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        isDark ? '검은 배경 + 흰 글씨' : '흰 배경 + 검은 글씨',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: scheme.onSurface.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    Text(
                      '알림',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: notificationsEnabled,
                      onChanged: (value) {
                        setModalState(() => notificationsEnabled = value);
                        setState(() {
                          _notificationsEnabled = value;
                          _applyNotificationDefault(value);
                        });
                        if (value) {
                          unawaited(_refreshAllNotifications());
                        } else {
                          unawaited(_cancelAllNotifications());
                        }
                      },
                      title: const Text('알림 받기'),
                      subtitle: Text(
                        notificationsEnabled
                            ? '설정한 리드 타임에 따라 시작/마감 알림이 울립니다.'
                            : '알림이 전송되지 않습니다.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: notificationsEnabled,
                      title: const Text('알림 리드 타임'),
                      subtitle: Text(
                        '알림을 얼마나 먼저 받을지 선택하세요.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$leadMinutes분 전',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: !notificationsEnabled
                          ? null
                          : () async {
                              final selected = await _pickLeadTimeMinutes(
                                context,
                                leadMinutes,
                              );
                              if (selected != null &&
                                  selected != _notificationLeadTime.inMinutes) {
                                setModalState(() => leadMinutes = selected);
                                setState(() {
                                  _notificationLeadTime =
                                      Duration(minutes: selected);
                                });
                                unawaited(_refreshAllNotifications());
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '그룹 관리',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '할 일 추가 시 사용할 그룹은 폼에서 선택하거나 새로 만들 수 있습니다.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _themes
                          .map(
                            (group) => Chip(
                              backgroundColor: group.color.withValues(alpha: 0.15),
                              label: Text(group.name),
                              avatar: CircleAvatar(
                                backgroundColor: group.color,
                                foregroundColor: Colors.white,
                                child: Text(
                                  group.name.trim().isEmpty
                                      ? 'G'
                                      : group.name.trim().substring(0, 1).toUpperCase(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final selected = await _showGroupManager(_defaultThemeId);
                        if (selected != null && _themeMap.containsKey(selected)) {
                          setState(() {
                            _defaultThemeId = selected;
                          });
                        }
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('그룹 관리 열기'),
                    ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.theme,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onOpenRoadmap,
  });

  final TodoItem item;
  final TodoTheme? theme;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenRoadmap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final timeLabel = _formatTimeRange(item);
    final themeColor = theme?.color ?? scheme.primary;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                color: item.isDone ? themeColor : Colors.transparent,
              ),
              child: item.isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (theme != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        theme!.name,
                        style: textTheme.bodySmall?.copyWith(
                          color: themeColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            Text(
                    item.title,
                    style: textTheme.titleMedium?.copyWith(
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                      color: item.isDone
                          ? scheme.onSurface.withValues(alpha: 0.55)
                          : scheme.onSurface,
                    ),
                  ),
                  if (timeLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        timeLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if ((item.memo ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.memo!.trim(),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        if (item.notify && item.hasAnyTime)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                        Text(
                          item.isDone ? '완료됨' : '진행 중',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
            ),
          ],
        ),
      ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onOpenRoadmap != null)
              IconButton(
                onPressed: onOpenRoadmap,
                icon: const Icon(Icons.route_outlined),
                tooltip: '로드맵에서 수정',
                visualDensity: VisualDensity.compact,
                color: scheme.primary,
              ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: '수정',
              visualDensity: VisualDensity.compact,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
              visualDensity: VisualDensity.compact,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange(TodoItem todo) {
    final start = todo.startTime != null ? _formatTimeOfDay(todo.startTime!) : '';
    final end = todo.endTime != null ? _formatTimeOfDay(todo.endTime!) : '';
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isNotEmpty && end.isNotEmpty) return '$start ~ $end';
    if (start.isNotEmpty) return '$start ~';
    return '~ $end';
  }
}

class _PaletteEntry {
  _PaletteEntry({
    required this.onTap,
    required this.selected,
    required this.color,
  }) : isPlus = false;

  _PaletteEntry.plus({
    required this.onTap,
    required this.selected,
    this.color,
  }) : isPlus = true;

  final Color? color;
  final bool selected;
  final bool isPlus;
  final VoidCallback onTap;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.selectedDay});

  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Color.fromARGB(64, 255, 255, 255),
          ),
          SizedBox(height: 16),
          Text('이 날의 일정이 없습니다.'),
        ],
      ),
    );
  }
}

class _AdaptiveCenterFloatFabLocation extends FloatingActionButtonLocation {
  const _AdaptiveCenterFloatFabLocation(this.bottomPadding);

  final double bottomPadding;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final double fabX =
        (geometry.scaffoldSize.width - geometry.floatingActionButtonSize.width) / 2;
    final double fabY = geometry.scaffoldSize.height -
        geometry.floatingActionButtonSize.height -
        bottomPadding;
    return Offset(fabX, fabY);
  }

  @override
  String get debugDescription => 'adaptiveCenterFloat';
}

class _NoOpFabAnimator extends FloatingActionButtonAnimator {
  const _NoOpFabAnimator();

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) =>
      end;

  @override
  Animation<double> getScaleAnimation({
    required Animation<double> parent,
  }) =>
      const AlwaysStoppedAnimation<double>(1.0);

  @override
  Animation<double> getRotationAnimation({
    required Animation<double> parent,
  }) =>
      const AlwaysStoppedAnimation<double>(0.0);
}

class _RoadmapSessionListSheet extends StatelessWidget {
  const _RoadmapSessionListSheet({
    required this.sessions,
    required this.useDatabase,
  });

  final List<RoadmapSession> sessions;
  final bool useDatabase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '로드맵 채팅',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (!useDatabase)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '웹/테스트 환경에서는 대화가 임시로만 보관됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '아직 저장된 로드맵 대화가 없습니다.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final createdAt = DateFormat('yyyy.MM.dd HH:mm')
                        .format(session.createdAt);
                    final title = session.goal?.isNotEmpty == true
                        ? session.goal!
                        : '로드맵 대화';
                    final summary = session.summary.isNotEmpty
                        ? session.summary
                        : '요약 없음';
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$createdAt · ${summary.replaceAll('\n', ' ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(session),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('new'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('새로운 로드맵 대화 시작'),
            ),
          ],
        ),
      ),
    );
  }
}

class RoadmapChatPage extends StatefulWidget {
  const RoadmapChatPage({
    required this.useDatabase,
    required this.onImport,
    required this.onSessionChanged,
    required this.defaultStartDate,
    required this.themeMap,
    required this.defaultThemeId,
    this.session,
    this.initialMessages = const [],
    super.key,
  });

  final bool useDatabase;
  final RoadmapSession? session;
  final List<RoadmapChatMessage> initialMessages;
  final Future<void> Function(RoadmapResult, RoadmapSaveResult?, {String? themeId}) onImport;
  final void Function(RoadmapSession session, List<RoadmapChatMessage> messages)
      onSessionChanged;
  final DateTime defaultStartDate;
  final Map<String, TodoTheme> themeMap;
  final String defaultThemeId;

  @override
  State<RoadmapChatPage> createState() => _RoadmapChatPageState();
}

class _RoadmapChatPageState extends State<RoadmapChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _apiKeyController = TextEditingController();
  final Uuid _uuid = const Uuid();

  late List<RoadmapChatMessage> _messages;
  RoadmapSession? _session;
  RoadmapResult? _lastResult;
  RoadmapSaveResult? _lastSaveResult;
  DateTime _preferredStartDate = DateTime.now();
  bool _isGenerating = false;
  String? _apiKey;
  String? _progressMessage;
  StreamSubscription<RoadmapProgress>? _progressSubscription;

  // 기존 세션에서도 수정 요청 가능
  bool get _isReadOnly => false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _messages = List<RoadmapChatMessage>.from(widget.initialMessages);
    _lastResult = widget.session?.result;
    _preferredStartDate = widget.session?.preferredStartDate ??
        DateUtils.dateOnly(widget.defaultStartDate);
    if (_session != null) {
      final result = _session!.result;
      if (result != null) {
        _lastSaveResult = RoadmapSaveResult(
          sessionId: _session!.id,
          taskIdMap: {
            for (final entry in result.timeline) entry.id: _uuid.v4(),
          },
        );
      } else {
        _lastSaveResult = RoadmapSaveResult(sessionId: _session!.id, taskIdMap: const {});
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _apiKeyController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _session?.goal?.isNotEmpty == true
        ? _session!.goal!
        : (_isReadOnly ? '로드맵 대화' : '새 로드맵 대화');
    final startLabel = DateFormat('yyyy.MM.dd (E)', 'ko_KR')
        .format(_preferredStartDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _apiKey == null ? 'API 키 입력' : 'API 키 수정',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: _promptForApiKey,
          ),
          if (!_isReadOnly)
            IconButton(
              tooltip: '시작일 선택: $startLabel',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _pickPreferredStartDate,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              itemCount: _messages.length + (_isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isGenerating && index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ProgressBubble(
                        message: _progressMessage ?? '처리 중...',
                      ),
                    ),
                  );
                }
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _ChatBubble(
                    message: message,
                    alignRight: message.role == 'user',
                  ),
                );
              },
            ),
          ),
          if (_lastResult != null)
            _RoadmapResultSummary(
              result: _lastResult!,
              onImport: (themeId) => widget.onImport(_lastResult!, _lastSaveResult, themeId: themeId),
              themeMap: widget.themeMap,
              defaultThemeId: widget.defaultThemeId,
            ),
          const Divider(height: 1),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    if (_isReadOnly) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(16),
        child: Text(
          '저장된 대화입니다. 새로운 메시지를 보내려면 신규 로드맵 대화를 시작하세요.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final canSend = !_isGenerating;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _apiKey == null
                      ? '먼저 API 키를 입력하세요'
                      : '로드맵으로 바꿔줄 요청을 입력하세요',
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                enabled: canSend,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canSend ? _handleSend : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('보내기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OpenAI API 키를 먼저 입력해주세요.')),
      );
      return;
    }

    final now = DateTime.now();
    final tempMessage = RoadmapChatMessage(
      id: _uuid.v4(),
      sessionId: _session?.id ?? '',
      role: 'user',
      message: text,
      createdAt: now,
    );

    setState(() {
      _messages = [..._messages, tempMessage];
      _isGenerating = true;
    });
    _scrollToBottom();
    _inputController.clear();

    try {
      RoadmapResult? result;
      final completer = Completer<RoadmapResult>();
      Exception? streamError;

      // Stream으로 진행 상황 구독
      _progressSubscription?.cancel();
      
      // 기존 세션이 있으면 이전 대화와 로드맵 결과를 전달
      final previousMessages = _session != null ? _messages : null;
      final previousResult = _lastResult;
      
      _progressSubscription = RoadmapService.generateRoadmapStream(
        request: text,
        apiKey: _apiKey!,
        preferredStartDate: _preferredStartDate,
        previousMessages: previousMessages,
        previousResult: previousResult,
      ).listen(
        (progress) {
          if (!mounted) return;
          setState(() {
            _progressMessage = progress.message;
            if (progress.result != null) {
              result = progress.result;
              if (!completer.isCompleted) {
                completer.complete(progress.result);
              }
            }
          });
        },
        onError: (error) {
          streamError = error is Exception ? error : Exception(error.toString());
          if (!completer.isCompleted) {
            completer.completeError(streamError!);
          }
        },
        onDone: () {
          if (result == null && !completer.isCompleted) {
            completer.completeError(
              StateError('로드맵 생성 결과를 받지 못했습니다.'),
            );
          }
        },
      );

      // Stream이 완료될 때까지 대기
      result = await completer.future;

      if (widget.useDatabase) {
        final isExistingSession = _session != null;
        
        if (isExistingSession) {
          // 기존 세션 업데이트: 로드맵 결과 업데이트 및 새 메시지 추가
          await RoadmapRepository.instance.updateSession(
            sessionId: _session!.id,
            result: result!,
            preferredStartDate: _preferredStartDate,
          );
          
          // 새 메시지들을 DB에 추가
          await RoadmapRepository.instance.appendChatMessage(
            sessionId: _session!.id,
            role: 'user',
            message: text,
            createdAt: now,
          );
          
          await RoadmapRepository.instance.appendChatMessage(
            sessionId: _session!.id,
            role: 'assistant',
            message: result!.summary,
            createdAt: DateTime.now(),
          );
          
          // 업데이트된 세션과 채팅 로그 불러오기
          final updatedSession =
              await RoadmapRepository.instance.fetchSession(_session!.id);
          final chatLogs =
              await RoadmapRepository.instance.fetchChatLogs(_session!.id);

          if (!mounted) return;
          if (updatedSession != null) {
            setState(() {
              _session = updatedSession;
              _messages = chatLogs; // 전체 채팅 로그 (기존 + 새 메시지)
              _lastResult = updatedSession.result ?? result;
              _isGenerating = false;
              _progressMessage = null;
            });
            widget.onSessionChanged(updatedSession, chatLogs);
          }
        } else {
          // 새 세션 생성
          final saveResult = await RoadmapRepository.instance.saveGeneration(
            userRequest: text,
            result: result!,
            requestedAt: now,
            preferredStartDate: _preferredStartDate,
          );
          final session =
              await RoadmapRepository.instance.fetchSession(saveResult.sessionId);
          final chatLogs =
              await RoadmapRepository.instance.fetchChatLogs(saveResult.sessionId);

          if (!mounted) return;
          if (session != null) {
            setState(() {
              _session = session;
              _messages = chatLogs;
              _lastResult = session.result ?? result;
              _lastSaveResult = saveResult;
              _isGenerating = false;
              _progressMessage = null;
            });
            widget.onSessionChanged(session, chatLogs);
          } else {
            setState(() {
              _lastResult = result;
              _lastSaveResult = saveResult;
              _isGenerating = false;
              _progressMessage = null;
            });
          }
        }
      } else {
        final sessionId = _session?.id ?? _uuid.v4();
        final userMessage = RoadmapChatMessage(
          id: tempMessage.id,
          sessionId: sessionId,
          role: 'user',
          message: text,
          createdAt: now,
        );
        final assistantMessage = RoadmapChatMessage(
          id: _uuid.v4(),
          sessionId: sessionId,
          role: 'assistant',
          message: result!.summary,
          createdAt: DateTime.now(),
        );
        final taskIdMap = <String, String>{
          for (final entry in result!.timeline) entry.id: _uuid.v4(),
        };
        final saveResult =
            RoadmapSaveResult(sessionId: sessionId, taskIdMap: taskIdMap);
        final newSession = RoadmapSession(
          id: sessionId,
          userRequest: text,
          summary: result!.summary,
          createdAt: now,
          goal: result!.goal,
          preferredStartDate: _preferredStartDate,
          result: result,
        );

        if (!mounted) return;
        setState(() {
          _session = newSession;
          _messages = [userMessage, assistantMessage];
          _lastResult = result;
          _lastSaveResult = saveResult;
          _isGenerating = false;
        });
        widget.onSessionChanged(newSession, _messages);
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _messages = List<RoadmapChatMessage>.from(_messages)
          ..add(
            RoadmapChatMessage(
              id: _uuid.v4(),
              sessionId: _session?.id ?? '',
              role: 'assistant',
              message: '로드맵 생성에 실패했습니다. 재시도 횟수를 초과했습니다.\n\n오류: $e',
              createdAt: DateTime.now(),
            ),
          );
      });
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로드맵 생성에 실패했습니다: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _promptForApiKey() async {
    _apiKeyController.text = _apiKey ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('OpenAI API 키 입력'),
          content: TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              hintText: 'sk-로 시작하는 키를 입력하세요',
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() {
        _apiKey = _apiKeyController.text.trim();
      });
    }
  }

  Future<void> _pickPreferredStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredStartDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _preferredStartDate = DateUtils.dateOnly(picked);
      });
    }
  }
}

class _ProgressBubble extends StatelessWidget {
  const _ProgressBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.alignRight});

  final RoadmapChatMessage message;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = alignRight
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = alignRight
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft:
                  alignRight ? const Radius.circular(18) : Radius.zero,
              bottomRight:
                  alignRight ? Radius.zero : const Radius.circular(18),
            ),
          ),
          child: Column(
            crossAxisAlignment: alignRight
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.role == 'assistant')
                MarkdownBody(
                  data: message.message,
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    strong: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    em: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontStyle: FontStyle.italic,
                    ),
                    code: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontFamily: 'monospace',
                      backgroundColor: textColor.withValues(alpha: 0.1),
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    codeblockPadding: const EdgeInsets.all(8),
                    listBullet: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    h1: theme.textTheme.headlineSmall?.copyWith(color: textColor),
                    h2: theme.textTheme.titleLarge?.copyWith(color: textColor),
                    h3: theme.textTheme.titleMedium?.copyWith(color: textColor),
                  ),
                  selectable: true,
                )
              else
                Text(
                  message.message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              const SizedBox(height: 6),
              Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadmapResultSummary extends StatefulWidget {
  const _RoadmapResultSummary({
    required this.result,
    required this.onImport,
    required this.themeMap,
    required this.defaultThemeId,
  });

  final RoadmapResult result;
  final Future<void> Function(String themeId) onImport;
  final Map<String, TodoTheme> themeMap;
  final String defaultThemeId;

  @override
  State<_RoadmapResultSummary> createState() => _RoadmapResultSummaryState();
}

class _RoadmapResultSummaryState extends State<_RoadmapResultSummary> {
  bool _isExpanded = true;
  late String _selectedThemeId;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.defaultThemeId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '로드맵 요약',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_more : Icons.expand_less,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    Text(
                      widget.result.summary,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '단계별 일정',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.result.timeline.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.title} · ${dateFormat.format(entry.start)} ~ ${dateFormat.format(entry.end)}'
                                ' (${entry.durationDays}일)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.subtasks
                                    .map(
                                      (sub) => Chip(
                                        label: Text('${sub.title} (${sub.durationDays}일)'),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedThemeId,
                            decoration: InputDecoration(
                              labelText: '그룹 선택',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: widget.themeMap.entries.map((entry) {
                              final theme = entry.value;
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(theme.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(theme.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedThemeId = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            widget.onImport(_selectedThemeId);
                          },
                          child: const Text('할 일에 추가'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CalendarArrowButton extends StatelessWidget {
  const _CalendarArrowButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: 18,
        iconSize: 20,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour시 $minute분';
}

class _TodoFormResult {
  _TodoFormResult({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.themeId,
    this.memo,
    this.startTime,
    this.endTime,
    this.notify = true,
    this.delete = false,
  });

  factory _TodoFormResult.delete() {
    final now = DateTime.now();
    return _TodoFormResult(
      title: '',
      startDate: now,
      endDate: now,
      themeId: 'default',
      notify: false,
      delete: true,
    );
  }

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String themeId;
  final String? memo;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool notify;
  final bool delete;

  bool get isDeleteRequest => delete;
}
 
 







































