import 'package:porelo_host/porelo_host.dart';

/// The public entries retained from a host session, without raw wire objects or login answers.
sealed class HostProtocolEntry {
  const HostProtocolEntry();

  /// The explicit fields that may reach the settings file.
  Map<String, Object?> get stored;

  /// Checks every recognized field before restoring any of the protocol.
  static List<HostProtocolEntry>? readMany(Object? value) {
    if (value is! List) return null;
    final entries = <HostProtocolEntry>[];
    for (final item in value) {
      if (item is! Map) return null;
      switch (item['kind']) {
        case 'line':
          final text = item['text'];
          if (text is! String) return null;
          entries.add(HostProtocolLine(text));
        case 'interruption':
          final at = _instant(item['at']);
          if (at == null) return null;
          entries.add(HostProtocolInterruption(at));
        case 'step':
          final name = item['name'];
          final state = StepState.values.where((state) => state.name == item['state']).firstOrNull;
          final text = item['text'];
          final words = item['words'];
          final fix = item['fix'];
          final seconds = item['seconds'];
          final current = item['current'];
          final startedAt = _instant(item['startedAt']);
          final endedAt = _instant(item['endedAt']);
          if (name is! String ||
              name.isEmpty ||
              name.contains('\x00') ||
              state == null ||
              state == StepState.plan ||
              text is! String ||
              words != null && words is! String ||
              fix != null && fix is! String ||
              seconds != null && (seconds is! int || seconds < 0) ||
              current is! bool ||
              startedAt == null ||
              item['endedAt'] != null && endedAt == null) {
            return null;
          }
          entries.add(
            HostProtocolStep(
              name: name,
              state: state,
              text: text,
              words: words is String ? words : null,
              fix: fix is String ? fix : null,
              seconds: seconds is int ? seconds : null,
              current: current,
              startedAt: startedAt,
              endedAt: endedAt,
            ),
          );
        default:
          return null;
      }
    }
    return List.unmodifiable(entries);
  }

  static DateTime? _instant(Object? value) {
    if (value is! String) return null;
    final instant = DateTime.tryParse(value);
    return instant != null && instant.isUtc && instant.toIso8601String() == value ? instant : null;
  }
}

/// One step's recorded words and timing, including which attempt it belongs to.
class HostProtocolStep extends HostProtocolEntry {
  /// Keeps the step's public presentation rather than its raw wire fields.
  const HostProtocolStep({
    required this.name,
    required this.state,
    required this.text,
    required this.startedAt,
    required this.current,
    this.endedAt,
    this.seconds,
    this.words,
    this.fix,
  });

  /// The task identity emitted by the host.
  final String name;

  /// The last state emitted for this step.
  final StepState state;

  /// The recorded public words, including any plan fallback.
  final String text;

  /// The public result emitted by the step.
  final String? words;

  /// The public explanation of how to address a refusal.
  final String? fix;

  /// The first event's instant.
  final DateTime startedAt;

  /// The last terminal event's instant, absent while unfinished.
  final DateTime? endedAt;

  /// The usual duration supplied by the host, in seconds.
  final int? seconds;

  /// Whether the step belongs to the latest attempt.
  final bool current;

  @override
  Map<String, Object?> get stored => {
    'kind': 'step',
    'name': name,
    'state': state.name,
    'text': text,
    if (words != null) 'words': words,
    if (fix != null) 'fix': fix,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    if (seconds != null) 'seconds': seconds,
    'current': current,
  };
}

/// An unmatched public diagnostic, retained in its place among the steps.
class HostProtocolLine extends HostProtocolEntry {
  /// Keeps a diagnostic already recorded for a person.
  const HostProtocolLine(this.text);

  /// The recorded public words, including any plan fallback.
  final String text;
  @override
  Map<String, Object?> get stored => {'kind': 'line', 'text': text};
}

/// The instant a free project lock confirmed that the earlier attempt had ended.
class HostProtocolInterruption extends HostProtocolEntry {
  /// Keeps the confirmed instant rather than recomputing it on each restart.
  const HostProtocolInterruption(this.at);

  /// The first observed interruption instant.
  final DateTime at;
  @override
  Map<String, Object?> get stored => {'kind': 'interruption', 'at': at.toUtc().toIso8601String()};
}
