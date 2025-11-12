import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:todo_calendar_demo/data/local_database.dart';
import 'package:todo_calendar_demo/main.dart';
import 'package:todo_calendar_demo/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    NotificationService.setTestMode(true);
    tempDir = await Directory.systemTemp.createTemp('todo_calendar_test');
    TodoDatabase.overrideDirectory(tempDir);
    TodoDatabase.setTestMode(true);
    await initializeDateFormatting('ko_KR');
    await TodoDatabase.instance.init();
  });

  tearDownAll(() async {
    await TodoDatabase.instance.close();
    if (tempDir != null && await tempDir!.exists()) {
      await tempDir!.delete(recursive: true);
    }
    TodoDatabase.overrideDirectory(null);
    TodoDatabase.setTestMode(false);
  });

  testWidgets(
      'Ordoo 데모 화면이 샘플 데이터를 렌더링한다', (WidgetTester tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1080, 1920);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TodoCalendarApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Ordoo'), findsOneWidget);
    expect(find.text('UI 윤곽 잡기'), findsOneWidget);
    expect(find.text('핵심 기능 정리'), findsOneWidget);

    await tester.tap(find.byTooltip('할 일 추가'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('할 일 추가'), findsOneWidget);
  });
}

