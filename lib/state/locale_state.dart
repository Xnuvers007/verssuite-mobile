import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locale switching between EN and ID.
class LocaleState extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  bool _userChanged = false;

  LocaleState() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('locale');
      if (code != null && code.isNotEmpty && !_userChanged) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (e) {
      print('[LocaleState] Load locale error: $e');
    }
  }

  void setLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) return;
    _userChanged = true;
    _locale = locale;
    notifyListeners(); // Synchronously notify listeners immediately!

    // Asynchronously save to SharedPreferences in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('locale', locale.languageCode);
    }).catchError((e) {
      print('[LocaleState] Save locale error: $e');
    });
  }

  bool get isEnglish => _locale.languageCode == 'en';

  void toggle() {
    setLocale(isEnglish ? const Locale('id') : const Locale('en'));
  }
}
