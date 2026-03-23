import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

/// Provider for managing app locale/language
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en', '');
  
  Locale get locale => _locale;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  /// Load saved locale preference
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code');
      if (languageCode != null) {
        _locale = Locale(languageCode);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading locale: $e');
    }
  }
  
  /// Set locale and save preference
  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales.contains(locale)) {
      return;
    }
    
    _locale = locale;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
    } catch (e) {
      print('Error saving locale: $e');
    }
  }
  
  /// Get language name
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'zu':
        return 'isiZulu';
      case 'xh':
        return 'isiXhosa';
      case 'af':
        return 'Afrikaans';
      case 'st':
        return 'Sesotho';
      default:
        return 'English';
    }
  }
  
  /// Get current language name
  String get currentLanguageName => getLanguageName(_locale.languageCode);
}


