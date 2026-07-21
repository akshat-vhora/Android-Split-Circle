import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._();
  static LoggerService get instance => _instance;
  LoggerService._();

  void log(LogLevel level, String message, [dynamic error, StackTrace? stack]) {
    final prefix = switch (level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warn => '[WARN]',
      LogLevel.error => '[ERROR]',
    };
    debugPrint('$prefix $message');
    if (error != null) {
      debugPrint('$prefix Error details: $error');
    }
    if (stack != null) {
      debugPrint('$prefix Stack trace: $stack');
    }
  }

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warn(String message) => log(LogLevel.warn, message);
  void error(String message, [dynamic err, StackTrace? stack]) =>
      log(LogLevel.error, message, err, stack);
}
