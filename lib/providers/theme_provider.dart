import 'package:flutter/material.dart';
import "package:shared_preferences/shared_preferences.dart";

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  Color _accentColor = Colors.cyanAccent;

  ThemeProvider() {
    loadPreferences();
  }

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool("isDarkMode") ?? false;
    int colorValue = prefs.getInt("accentColor") ?? Colors.cyan.value;
    _accentColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("isDarkMode", _isDarkMode);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("accentColor", _accentColor.value);
    notifyListeners();
  }
}