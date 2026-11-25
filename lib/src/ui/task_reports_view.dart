import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

import '../app/attention.dart' show Tile;
import '../app/settings.dart';
import '../app/window_log.dart';
import '../client/models.dart' show Task, TaskReport, TaskReports, mostReportsOfATask;
import '../client/porelo_client.dart' show FeatureNotSupported;
import '../wire/varlink_exception.dart';
import 'tokens.dart';

/// The most characters of a report's kind shown: it is one line its starter's brief asked for.
const mostKindCharacters = 80;

/// The most characters of a report's text shown, as Porelo bounds a report.
const mostReportCharacters = 65536;

/// The most characters of the machine's own words shown in a refusal.
const mostRefusalCharacters = 300;

/// Control characters but a line break, the line and paragraph separators, lone surrogates, the marks that turn the
/// order of text around, and the characters drawn as nothing (soft hyphens, joiners, word joiners, byte order marks,
/// tags): each would forge a line or hide what the text says.
final _unsafe = RegExp(
  '[\x00-\x09\x0b-\x1f\x7f-\x9f\u00ad\u034f\u061c\u180e\u200b-\u200f\u2028\u2029\u202a-\u202e\u2060-\u2069\ufeff]'
  '|\udb40[\udc00-\udc7f]'
  '|[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]',
);

/// [text] as a report is shown: cut past [most] characters, and every unsafe character of what is left written out as
/// `\u{...}`.
String reportShown(String text, {int most = mostReportCharacters}) {
  final runes = text.runes;
  final cut = runes.length > most;
  final kept = cut ? String.fromCharCodes(runes.take(most)) : text;
  final escaped = kept.replaceAllMapped(
    _unsafe,
    (match) => '\\u{${match[0]!.runes.first.toRadixString(16).padLeft(4, '0')}}',
  );
  return cut ? '$escaped … cut' : escaped;
}

/// [text] as one shown line of at most [most] characters: its line breaks written out too.
String oneLineShown(String text, {required int most}) => reportShown(text, most: most).replaceAll('\n', r'\n');

/// A report's kind as one line.
String reportKindShown(String kind) => switch (oneLineShown(kind, most: mostKindCharacters)) {
  final shown when shown.trim().isEmpty => 'no kind',
  final shown => shown,
};

/// The key reports seen are kept by: a digest of the task's run, of its container where the machine names none, so
/// whatever the machine wrote into it is kept as a short line.
String reportsRunOf(Task task) => crypto.sha256
    .convert(utf8.encode(task.run != null && task.run!.isNotEmpty ? task.run! : task.name))
    .toString()
    .substring(0, 32);

/// How many of [task]'s reports on [machine] the person has not seen, by [settings]; 0 where none are new or the
/// machine does not say.
int newReports(Settings settings, String machine, Task task) {
  final last = task.reports ?? 0;
  final seen = settings.reportsSeen(machine, task.name, reportsRunOf(task));
  return last > seen ? last - seen : 0;
}

/// Why the reports could not be read, in the machine's words, each on one line.
String reportsRefusedWords(Object error) {
  String said(String words) => oneLineShown(words, most: mostRefusalCharacters);
  return switch (error) {
    FeatureNotSupported() => 'This machine\'s Porelo does not answer Reports; it needs a newer Porelo.',
    VarlinkException(:final simpleName, :final parameters) => switch (parameters['reason']) {
      final String reason when reason.trim().isNotEmpty =>
        'The machine refused to show them: ${said(simpleName)} (${said(reason)}).',
      _ => 'The machine refused to show them: ${said(simpleName)}.',
    },
    VarlinkDisconnected(:final message) => 'Lost contact while reading them: ${said(message)}',
    FormatException(:final message) => 'The machine answered what this window cannot read: ${said(message)}.',
    _ => said('$error'),
  };
}

/// A task's reports, read from its machine when its row is opened and not before, oldest first; reading on where the
/// machine left some out, and again when the task makes a new one while it is open. Reading them is seeing them.
class TaskReportsView extends StatefulWidget {
  /// Takes the row's work and where reports seen are kept.
  const TaskReportsView({required this.tile, required this.settings, super.key});

  /// The row's work.
  final Tile tile;

  /// Where the reports seen are kept.
  final Settings settings;

  @override
  State<TaskReportsView> createState() => _TaskReportsViewState();
}

class _TaskReportsViewState extends State<TaskReportsView> {
  final _shown = <TaskReport>[];
  bool _more = false;
  bool _reading = false;
  String? _problem;

  /// The number the reports are read to: the last shown, or the task's last once read to the end.
  int _readTo = 0;

  /// Which task's reports are shown: a later task under the same name is another.
  String? _run;

  /// Counts each start over, so an answer read for what the row showed before is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startOver();
  }

  @override
  void didUpdateWidget(TaskReportsView old) {
    super.didUpdateWidget(old);
    final task = widget.tile.task;
    if (task == null ||
        reportsRunOf(task) != _run ||
        widget.tile.machine.name != old.tile.machine.name ||
        (task.reports ?? 0) < _readTo) {
      // Another task, or one whose numbers went back: nothing shown is its.
      _startOver();
    } else {
      _readOnIfNew();
    }
  }

  int get _highest => _shown.isEmpty ? 0 : _shown.last.seq;

  /// Reads a report the task made since, while nothing is left to read on and no refusal stands.
  void _readOnIfNew() {
    final task = widget.tile.task;
    if (task == null || _more || _reading || _problem != null) return;
    if ((task.reports ?? 0) > _readTo) unawaited(_read(after: _highest == 0 ? null : _highest));
  }

  void _startOver() {
    final task = widget.tile.task;
    _generation++;
    _reading = false;
    _shown.clear();
    _more = false;
    _problem = null;
    _readTo = 0;
    _run = task == null ? null : reportsRunOf(task);
    // A machine that does not say how many is asked all the same: its answer says whether it can.
    if (task != null && (task.reports == null || task.reports! > 0)) unawaited(_read());
  }

  Future<void> _read({int? after}) async {
    final task = widget.tile.task;
    if (task == null || _reading) return;
    final run = _run;
    final machine = widget.tile.machine.name;
    final generation = _generation;
    // Set without a rebuild: this may run while the row is built, which builds it after.
    _reading = true;
    try {
      final TaskReports page = await widget.tile.fleet.backend.taskReports(task.name, after: after);
      // An answer for a task this row no longer shows is not this one's.
      if (!mounted || generation != _generation) return;
      setState(() {
        _shown.addAll(page.reports.where((report) => report.seq > _highest).take(mostReportsOfATask - _shown.length));
        // Past the most a task may make, nothing more is read.
        _more = page.more && _shown.length < mostReportsOfATask;
        _problem = null;
        // Read to the end, every report up to the task's last is seen, also one the machine no longer keeps.
        _readTo = _more || page.last < _highest ? _highest : page.last;
      });
      if (_readTo > 0 && run != null) {
        // Kept beside the reading: the next page is not held back while the settings are written.
        unawaited(
          widget.settings.seeReports(machine, task.name, run, _readTo).catchError((Object error) {
            windowLog.warn('The reports seen of ${task.name} on $machine were not kept: $error');
          }),
        );
      }
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _problem = reportsRefusedWords(error));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _reading = false);
        // A report that came while this read was under way.
        _readOnIfNew();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.tile.task;
    if (task == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('tile-reports'),
      padding: const EdgeInsets.only(bottom: Space.small),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Reports', style: text.labelSmall),
          if (_problem case final problem?) ...<Widget>[
            Text(
              'Reports: $problem',
              key: const Key('tile-reports-refused'),
              style: text.bodySmall?.copyWith(color: scheme.error),
            ),
            TextButton(
              key: const Key('tile-reports-again'),
              onPressed: () => setState(_startOver),
              child: const Text('Try again'),
            ),
          ] else if (_shown.isEmpty)
            Text(
              switch ((_reading, _readTo)) {
                (true, _) => 'Reading them…',
                (false, 0) => 'No reports',
                // The machine keeps none of those the task made any more.
                _ => 'No reports kept',
              },
              key: const Key('tile-reports-none'),
              style: text.bodySmall,
            ),
          for (final report in _shown)
            Padding(
              key: ValueKey<String>('tile-report ${report.seq}'),
              padding: const EdgeInsets.only(top: Space.tight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    reportKindShown(report.kind),
                    key: ValueKey<String>('tile-report-kind ${report.seq}'),
                    style: text.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SelectableText(
                    reportShown(report.text),
                    key: ValueKey<String>('tile-report-text ${report.seq}'),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          if (_more)
            TextButton(
              key: const Key('tile-reports-more'),
              onPressed: _reading
                  ? null
                  : () => setState(() => unawaited(_read(after: _highest == 0 ? null : _highest))),
              child: const Text('Read more'),
            ),
        ],
      ),
    );
  }
}
