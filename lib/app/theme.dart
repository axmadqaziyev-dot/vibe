import 'package:flutter/material.dart';
const ink = Color(0xFF202039);
const violet = Color(0xFF7455E8);
const mint = Color(0xFFDAF5E9);
const canvasColor = Color(0xFFF8F7FC);
const brandGradient = LinearGradient(colors: [Color(0xFF7150DE), Color(0xFFAD71E8)], begin: Alignment.topLeft, end: Alignment.bottomRight);
ThemeData vibeTheme() => ThemeData(
  useMaterial3: true, scaffoldBackgroundColor: canvasColor,
  colorScheme: ColorScheme.fromSeed(seedColor: violet, surface: canvasColor),
  appBarTheme: const AppBarTheme(backgroundColor: canvasColor, foregroundColor: ink, centerTitle: false, scrolledUnderElevation: 0),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: ink, height: 1.15),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: ink),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: ink)),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E3EF))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE7E3EF)))),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    minimumSize: const Size(48,52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
  navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: violet.withValues(alpha: .12)),
  dividerTheme: const DividerThemeData(color: Color(0xFFECE9F2)),
);

