import 'package:flutter/material.dart';

class TodoTheme {
  const TodoTheme({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  final String id;
  final String name;
  final int colorValue;

  Color get color => Color(colorValue);

  TodoTheme copyWith({String? name, int? colorValue}) {
    return TodoTheme(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

