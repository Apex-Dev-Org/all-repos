import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide structured logging (singleton).
///
/// Uses [ProductionFilter] so logs are emitted in release builds; in release,
/// a compact [SimplePrinter] avoids heavy formatting while preserving timestamps.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  final Logger _logger = Logger(
    filter: ProductionFilter(),
    level: kReleaseMode ? Level.info : Level.trace,
    printer: kReleaseMode
        ? SimplePrinter(printTime: true, colors: false)
        : PrettyPrinter(
            methodCount: 2,
            errorMethodCount: 8,
            lineLength: 110,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
            noBoxingByDefault: true,
          ),
  );

  void debug(String message) => _logger.d(message);

  void info(String message) => _logger.i(message);

  void warning(String message) => _logger.w(message);

  /// [error] is typically an [Exception] or [Error] from a `catch` clause.
  void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Reserved for critical failures (e.g. global error handlers).
  void fatal(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
