import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appearance = ValueNotifier<int>(0);
const accentColors = [Color(0xff8b70f8), Color(0xffef79ae), Color(0xff49bfa5)];

class LoginMemory {
  LoginMemory(this.preferences);
  final SharedPreferences preferences;
  bool get remember => preferences.getBool('rememberMe') ?? true;
  String get email =>
      remember ? preferences.getString('rememberedEmail') ?? '' : '';
  Future<void> save(bool value, String email) async {
    await preferences.setBool('rememberMe', value);
    if (value) {
      await preferences.setString('rememberedEmail', email);
    } else {
      await preferences.remove('rememberedEmail');
    }
  }
}
