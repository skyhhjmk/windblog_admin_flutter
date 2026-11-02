import 'package:flutter/material.dart';
import 'storage_service.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> load() async {
    _themeMode = await StorageService.getThemeMode();
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await StorageService.saveThemeMode(mode);
  }

  Future<void> toggleThemeMode(BuildContext context) async {
    final currentBrightness = Theme.of(context).brightness;
    if (_themeMode == ThemeMode.system) {
      await setThemeMode(
        currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );
    } else if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
