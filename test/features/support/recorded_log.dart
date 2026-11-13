import 'package:porelo_frontend/src/app/window_log.dart';

/// The window's log as a scenario reads it: every entry kept in memory, at every level, and nothing written.
class RecordedLog extends WindowLog {
  /// Keeps what is written.
  RecordedLog() : super.off();

  /// Each entry, as `LEVEL [machine] words`.
  final lines = <String>[];

  @override
  void write(LogLevel at, String words, {String? machine}) =>
      lines.add('${at.word} ${machine == null ? '' : '[$machine] '}$words');
}
