import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDarkMode = false;

  ThemeMode get themeMode {
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme([bool? value]) {
    if (value == null) {
      isDarkMode = !isDarkMode;
    } else {
      isDarkMode = value;
    }

    notifyListeners();
  }
}