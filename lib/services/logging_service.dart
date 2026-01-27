import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  final List<String> _logHistory = [];
  static const int maxHistorySize = 1000;

  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  void _log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelName = level.name.toUpperCase();
    final logMessage = '[$timestamp] [$levelName] $message';

    // Add to history
    _logHistory.add(logMessage);
    if (_logHistory.length > maxHistorySize) {
      _logHistory.removeAt(0);
    }

    // Print based on level
    if (kDebugMode) {
      switch (level) {
        case LogLevel.debug:
          debugPrint('🐛 $logMessage');
          break;
        case LogLevel.info:
          debugPrint('ℹ️ $logMessage');
          break;
        case LogLevel.warning:
          debugPrint('⚠️ $logMessage');
          break;
        case LogLevel.error:
          debugPrint('❌ $logMessage');
          if (error != null) {
            debugPrint('Error: $error');
          }
          if (stackTrace != null) {
            debugPrint('Stack trace: $stackTrace');
          }
          break;
      }
    } else {
      // In release mode, only log errors
      if (level == LogLevel.error) {
        print(logMessage);
        if (error != null) {
          print('Error: $error');
        }
      }
    }
  }

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  List<String> getLogHistory() => List.unmodifiable(_logHistory);

  void clearHistory() {
    _logHistory.clear();
  }
}

// Global logger instance
final logger = LoggingService();


