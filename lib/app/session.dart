import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repository.dart';
import '../domain/models.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this.preferences) : code = preferences?.getString('language') ?? 'en';
  final SharedPreferences? preferences;
  String code;
  void setLanguage(String value) {
    code = value;
    preferences?.setString('language', value);
    notifyListeners();
  }
}
class Session extends InheritedWidget {
  const Session({super.key, required this.repository, required this.profile,
    required this.settings, required this.refresh, required this.exit, required super.child});
  final VibeRepository repository;
  final Profile profile;
  final AppSettings settings;
  final VoidCallback refresh;
  final Future<void> Function() exit;
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Session>()!;
  @override bool updateShouldNotify(Session oldWidget) => profile != oldWidget.profile;
}

