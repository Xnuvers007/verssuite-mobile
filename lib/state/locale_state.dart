import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locale switching between EN and ID.
class LocaleState extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  LocaleState() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'en';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }

  bool get isEnglish => _locale.languageCode == 'en';

  void toggle() {
    setLocale(isEnglish ? const Locale('id') : const Locale('en'));
  }
}
