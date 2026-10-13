import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings({SharedPreferences? preferences}) : _preferences = preferences {
    lightweightGlass = preferences?.getBool('lightweightGlass') ?? false;
    final saved = preferences?.getString('themeMode');
    themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }
  final SharedPreferences? _preferences;
  late bool lightweightGlass;
  late ThemeMode themeMode;
  Future<void> setLightweightGlass(bool value) async {
    lightweightGlass = value;
    notifyListeners();
    await _preferences?.setBool('lightweightGlass', value);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    await _preferences?.setString('themeMode', value.name);
  }
}
