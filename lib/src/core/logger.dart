import 'dart:developer' as developer;

/// Log levels for the Reddit Pixel library.
enum LogLevel {
  /// Debug information for development.
  debug,

  /// General information about operations.
  info,

  /// Warning about potential issues.
  warning,

  /// Error that may affect functionality.
  error,
}

/// Internal logger for the Reddit Pixel library.
///
/// Provides conditional logging based on debug mode. All logs are prefixed
/// with `[RedditPixel]` for easy identification in the console.
class RedditPixelLogger {
  RedditPixelLogger._();

  static bool _debugMode = false;

  /// Enable or disable debug logging.
  static void setDebugMode({required bool enabled}) {
    _debugMode = enabled;
  }

  /// Whether debug mode is enabled.
  static bool get isDebugMode => _debugMode;

  /// Log a debug message.
  ///
  /// Only logs when debug mode is enabled.
  static void debug(String message) {
    if (_debugMode) {
      _log(message, level: LogLevel.debug);
    }
  }

  /// Log an info message.
  ///
  /// Only logs when debug mode is enabled.
  static void info(String message) {
    if (_debugMode) {
      _log(message, level: LogLevel.info);
    }
  }

  /// Log a warning message.
  ///
  /// Always logs regardless of debug mode.
  static void warning(String message) {
    _log(message, level: LogLevel.warning);
  }

  /// Log an error message with optional error and stack trace.
  ///
  /// Always logs regardless of debug mode.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log(
    String message, {
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = switch (level) {
      LogLevel.debug => 'DEBUG',
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARNING',
      LogLevel.error => 'ERROR',
    };

    final logLevel = switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
    };

    developer.log(
      '[$prefix] $message',
      name: 'RedditPixel',
      level: logLevel,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
