import 'package:flutter/material.dart';

// Material Design 3 theme, readable on 360px screens.
final finMateTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C5B)),
  inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
);
