import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Helper class to simplify localization usage
class L {
  /// Get localized string with fallback
  static String t(BuildContext context, String key, {String? fallback}) {
    final localizations = AppLocalizations.of(context);
    return localizations?.translate(key) ?? fallback ?? key;
  }
  
  /// Get AppLocalizations instance
  static AppLocalizations? of(BuildContext context) {
    return AppLocalizations.of(context);
  }
}


