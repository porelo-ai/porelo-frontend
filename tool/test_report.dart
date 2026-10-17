// Turns one test run into a report of every feature file and its scenarios, in four shapes at once:
// an HTML page, JUnit XML grouped by feature file, a `$GITHUB_STEP_SUMMARY` table, and an `::error`
// per failing scenario. Why each is shaped the way it is: AGENTS.md, "What the build reports".
// ignore_for_file: avoid_print - this is a command-line tool; printing is its output.
//
// Usage:
//   flutter test --machine > build/test-results.json
//   dart tool/test_report.dart [results.json] [report.html] [results.xml]
//
// The two GitHub surfaces are separate switches, so both can be driven from a terminal:
//   GITHUB_ACTIONS=true GITHUB_STEP_SUMMARY=/tmp/summary.md dart tool/test_report.dart
import 'dart:convert';
import 'dart:io';

/// The summary's heading, and what the run was against: `--heading=` and `--against=`.
String _heading = 'Scenarios';
String _against = 'a fake backend, in a widget-test frame';

Future<void> main(List<String> arguments) async {
  final args = <String>[
    for (final argument in arguments)
      if (argument.startsWith('--heading='))
        ...(() {
          _heading = argument.substring('--heading='.length);
          return <String>[];
        })()
      else if (argument.startsWith('--against='))
        ...(() {
          _against = argument.substring('--against='.length);
          return <String>[];
        })()
      else
        argument,
  ];
  final source = File(args.isNotEmpty ? args[0] : 'build/test-results.json');
  final target = File(args.length > 1 ? args[1] : 'build/test-report.html');
  final junit = File(args.length > 2 ? args[2] : 'build/test-results.xml');

  if (!source.existsSync()) {
    await _sayNothingRan('There is no test output at `${source.path}`.');
    stderr.writeln('No test output at ${source.path}.');
    stderr.writeln('Run: flutter test --machine > ${source.path}');
    exitCode = 1;
    return;
  }

  final run = _read(source);
  if (run.results.isEmpty) {
    await _sayNothingRan('`${source.path}` holds no test results.');
    stderr.writeln('${source.path} contains no test results.');
    exitCode = 1;
    return;
  }

  await target.parent.create(recursive: true);
  await target.writeAsString(_page(run));
  await junit.parent.create(recursive: true);
  await junit.writeAsString(_junit(run));

  // Absent means "not on a runner", and both switches are read separately: a summary written to a
  // file nobody set would go nowhere, and an annotation printed outside Actions is noise in a
  // terminal.
  final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryFile != null && summaryFile.isNotEmpty) {
    await File(summaryFile).writeAsString(_summary(run), mode: FileMode.append);
  }
  if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
    for (final line in _annotations(run)) {
      print(line);
    }
  }

  final failed = run.results.where((result) => !result.passed).length;
  final skipped = run.results.where((result) => result.skipped).toList();
  print('${target.path}: ${run.results.length} tests, ${_verdict(failed, skipped.length)}');
  for (final result in skipped) {
    print('  skipped: ${result.name} (${_shorten(result.suite)})');
  }
  print('${junit.path}: grouped by feature');
  if (failed > 0) exitCode = 1;
}

/// One scenario or test, as it ran.
class Result {
  Result({required this.name, required this.suite, required this.group});

  /// Full name, which for a scenario is the feature line followed by the scenario.
  final String name;

  /// The file it came from.
  final String suite;

  /// The group it was in, which for a feature file is the `Feature:` line.
  final String group;

  /// Whether it passed. A skipped test did not fail, and [skipped] says it did not pass either.
  bool passed = true;

  /// Whether it was skipped, and so checked nothing.
  ///
  /// **Never counted as passed.** `--machine` reports a skip as `result: success`, and read that way
  /// the live daemon's tests showed as ticks — the one check whose absence matters.
  bool skipped = false;

  /// Whether it ran and passed.
  bool get held => passed && !skipped;

  /// How long it took.
  ///
  /// **Worked out, not read.** `--machine` reports `time` as milliseconds *since the run began*,
  /// on both `testStart` and `testDone` — so taking `testDone.time` as a duration made each row
  /// the age of the run at that point, and a column of them summed to four times the wall clock.
  Duration took = Duration.zero;

  /// When it started, in run time, so [took] can be the difference.
  Duration began = Duration.zero;

  /// Everything the run said about it going wrong.
  final List<String> problems = <String>[];

  /// What the test framework printed while it ran.
  ///
  /// **This is where a widget test's real failure is.** The `error` event for one says only
  /// *"Test failed. See exception logs above."* — the expectation, the actual, and the `reason`
  /// are all in the printed dump. A report built on `error` alone tells a reader nothing at
  /// exactly the moment they need it, and it looks fine until something goes red.
  final List<String> printed = <String>[];

  /// The whole of what went wrong, printed dump first.
  String get detail {
    final said = <String>[
      ...printed.map((line) => line.trimRight()),
      ...problems.where((problem) => !problem.startsWith('Test failed. See exception logs above.')),
    ].where((line) => line.trim().isNotEmpty);
    return said.join('\n').trim();
  }

  /// The `.feature` this came from, or null for a test that is not a scenario.
  ///
  /// Found by asking the filesystem rather than by reading the name: a scenario's group is its
  /// `Feature:` line, which says what the file tests and nothing about where it lives.
  String? get feature {
    if (!suite.endsWith('_test.dart')) return null;
    final path = '${suite.substring(0, suite.length - '_test.dart'.length)}.feature';
    return File(path).existsSync() ? _relative(path) : null;
  }

  /// The last two segments of that path, which is what the table shows.
  static String shorten(String path) {
    final parts = path.split('/');
    return parts.length <= 2 ? path : parts.sublist(parts.length - 2).join('/');
  }

  /// The scenario without the feature in front of it.
  String get scenario => name.startsWith(group) ? name.substring(group.length).trim() : name;
}

/// Everything one run produced.
class Run {
  /// Results, in the order they finished.
  final List<Result> results = <Result>[];

  /// When it ran.
  DateTime at = DateTime.now();

  /// How long the whole run took.
  Duration took = Duration.zero;
}

Run _read(File source) {
  final run = Run();
  final suites = <int, String>{};
  final groups = <int, String>{};
  final open = <int, Result>{};

  for (final line in source.readAsLinesSync()) {
    if (!line.startsWith('{')) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;

    switch (decoded['type']) {
      case 'suite':
        final suite = decoded['suite'] as Map<String, dynamic>;
        suites[suite['id'] as int] = '${suite['path']}';
      case 'group':
        final group = decoded['group'] as Map<String, dynamic>;
        groups[group['id'] as int] = '${group['name'] ?? ''}';
      case 'testStart':
        final test = decoded['test'] as Map<String, dynamic>;
        // Hidden tests are the harness's own loading and tear-down steps, not anybody's work.
        if (test['metadata'] is Map && (test['metadata'] as Map)['hidden'] == true) {
          continue;
        }
        final ids = (test['groupIDs'] as List?)?.cast<int>() ?? const <int>[];
        final named = ids.map((id) => groups[id] ?? '').where((name) => name.isNotEmpty).toList();
        open[test['id'] as int] = Result(
          name: '${test['name']}',
          suite: suites[test['suiteID'] as int] ?? '',
          group: named.isEmpty ? '' : named.last,
        )..began = Duration(milliseconds: (decoded['time'] as num? ?? 0).toInt());
      case 'testDone':
        final result = open[decoded['testID'] as int];
        if (result == null) continue;
        if (decoded['hidden'] == true) {
          open.remove(decoded['testID']);
          continue;
        }
        result.passed = decoded['result'] == 'success';
        result.skipped = decoded['skipped'] == true;
        final ended = Duration(milliseconds: (decoded['time'] as num? ?? 0).toInt());
        result.took = ended > result.began ? ended - result.began : Duration.zero;
        run.results.add(result);
      case 'print':
        final result = open[decoded['testID'] as int];
        result?.printed.add('${decoded['message']}');
      case 'error':
        final result = open[decoded['testID'] as int];
        result?.problems.add('${decoded['error']}\n${decoded['stackTrace'] ?? ''}'.trimRight());
      case 'done':
        run.took = Duration(milliseconds: (decoded['time'] as num? ?? 0).toInt());
    }
  }
  return run;
}

/// Says on the run's own page that nothing ran.
///
/// **Silence covers three states**: no test step, a step that matched nothing, and a step whose
/// run never produced output. A reporter that writes nothing when it has nothing to report cannot
/// be told apart from one that never ran.
Future<void> _sayNothingRan(String because) async {
  final summaryFile = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (summaryFile == null || summaryFile.isEmpty) return;
  await File(summaryFile).writeAsString(
    '## $_heading\n\n**No tests ran.** $because\n\n'
    'Check that the test step ran, that it wrote the machine JSON, and that the path this was '
    'given is the one it wrote.\n\n',
    mode: FileMode.append,
  );
}

/// Scenarios by the `.feature` they came from, and everything else by suite.
///
/// **One grouping, used by every output.** Two would be two answers to one question.
({Map<String, List<Result>> features, Map<String, List<Result>> others}) _group(Run run) {
  final features = <String, List<Result>>{};
  final others = <String, List<Result>>{};
  for (final result in run.results) {
    final feature = result.feature;
    if (feature != null) {
      features.putIfAbsent(feature, () => <Result>[]).add(result);
    } else {
      others.putIfAbsent(result.suite, () => <Result>[]).add(result);
    }
  }
  return (features: features, others: others);
}

/// The run's page on GitHub: one row per feature, its scenarios folded into a ratio.
///
/// **Porelo's table, column for column**, so two reports of the same kind of run read the same way.
/// The path is the last two segments only: the table is scanned and the annotation is navigated,
/// and a full path in every row crowds out the sentence that says what broke.
///
/// **No failure detail here.** It goes to the annotation, capped, and to the HTML report in full.
/// A summary that carries a stack trace stops being a summary at the first red build.
String _summary(Run run) {
  final grouped = _group(run);
  final paths = grouped.features.keys.toList()..sort();
  final scenarios = grouped.features.values.expand((each) => each).toList();
  final passed = scenarios.where((result) => result.held).length;

  final out = StringBuffer()
    ..writeln('## $_heading')
    ..writeln()
    ..writeln('Run against $_against.')
    ..writeln();

  if (scenarios.isEmpty) {
    out
      ..writeln(
        '**No scenarios ran.** Nothing under `test/features` produced a result — check '
        'that the generated tests are current.',
      )
      ..writeln();
    _sayWhatWasSkipped(run, out);
    return out.toString();
  }

  out
    ..writeln('| | What it tests | Feature | | Time |')
    ..writeln('|---|---|---|---|---:|');
  for (final path in paths) {
    final under = grouped.features[path]!;
    final ran = under.where((result) => result.held).length;
    // Any failure marks the whole row, with the ratio carrying the nuance.
    final mark = under.every((result) => result.passed) ? ':white_check_mark:' : ':x:';
    final took = under.fold(Duration.zero, (all, one) => all + one.took);
    out.writeln(
      '| $mark | ${_markdown(_titleOf(under))} | `${Result.shorten(path)}` '
      '| $ran/${under.length} | ${_seconds(took)} |',
    );
  }

  out
    ..writeln()
    ..writeln('**$passed of ${scenarios.length} passed.**');

  final everythingElse = grouped.others.values.expand((tests) => tests).toList();
  // Said only when there are any: "0 tests guard the client" beside a tick is a blank that looks
  // like an answer, and it is what a single-file run would print every time.
  if (everythingElse.isNotEmpty) {
    final elseBroken = everythingElse.where((test) => !test.passed).length;
    out
      ..writeln()
      ..writeln(
        '${elseBroken == 0 ? ':white_check_mark:' : ':x:'} '
        '**${everythingElse.length}** tests guard the client, the wire and the rules rather '
        'than a screen${elseBroken == 0 ? '.' : ', and $elseBroken failed.'}',
      );
  }
  out.writeln();
  _sayWhatWasSkipped(run, out);
  return out.toString();
}

/// Every skipped test by name, because a count hides exactly the check whose absence matters.
void _sayWhatWasSkipped(Run run, StringBuffer out) {
  final skipped = run.results.where((result) => result.skipped).toList();
  if (skipped.isEmpty) return;
  out
    ..writeln('**Skipped, so not checked:**')
    ..writeln();
  for (final result in skipped) {
    out.writeln('- ${_markdown(result.name)} (`${_shorten(result.suite)}`)');
  }
  out.writeln();
}

/// What a feature says it tests, which is its `Feature:` line.
String _titleOf(List<Result> scenarios) => scenarios.first.group;

/// One `::error` per failing scenario, on its own line in its own `.feature` file.
///
/// **A workflow command is one line.** A newline in the message ends the command and prints the
/// rest as ordinary output, which only ever shows in the failure case — the case the whole report
/// exists for. Everything is percent-encoded, and the message is capped: an over-long annotation
/// arrives truncated at a point nobody chose, and the full text is in the summary and the log.
/// The part of a failure worth putting on one line beside the scenario.
///
/// The stack and the framework's own rules are in the log and in the summary; what belongs here is
/// the expectation, what was actually found, and the reason somebody wrote.
String _worthAnnotating(String detail) {
  final kept = <String>[];
  for (final line in detail.split('\n')) {
    if (line.startsWith('When the exception was thrown, this was the stack:')) break;
    // The framework's own banner and rules carry nothing a reader needs and would eat the cap.
    if (line.trimLeft().startsWith('══')) continue;
    if (line.trim().replaceAll(RegExp(r'[═╡╞─\s]'), '').isEmpty) continue;
    kept.add(line.trimRight());
  }
  return kept.join('\n').trim();
}

List<String> _annotations(Run run) {
  const cap = 900;
  final lines = <String>[];
  for (final result in run.results.where((result) => !result.passed)) {
    final where = _whereScenarioIs(result);
    var message = _worthAnnotating(result.detail);
    if (message.isEmpty) message = 'failed with nothing said';
    if (message.length > cap) {
      message = '${message.substring(0, cap)}… (see the run log)';
    }
    final title = result.feature == null ? result.name : '${result.group}: ${result.scenario}';
    final properties = <String>[
      if (where != null) 'file=${_property(where.file)}',
      if (where != null) 'line=${where.line}',
      'title=${_property(title)}',
    ].join(',');
    lines.add('::error $properties::${_command(message)}');
  }
  return lines;
}

/// Where a scenario is written, so the annotation lands on it rather than on generated code.
///
/// **The `.feature` file, never the generated test.** A person reading a red build has to change
/// the feature; the generated file is regenerated and would be the one place an edit is lost.
({String file, int line})? _whereScenarioIs(Result result) {
  final suite = result.suite;
  if (!suite.endsWith('_test.dart')) return null;
  final feature = File('${suite.substring(0, suite.length - '_test.dart'.length)}.feature');
  if (!feature.existsSync()) return null;

  final wanted = result.scenario;
  final lines = feature.readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (!line.startsWith('Scenario')) continue;
    final said = line.substring(line.indexOf(':') + 1).trim();
    if (said == wanted) {
      return (file: _relative(feature.path), line: index + 1);
    }
  }
  // The file is better than nothing: a scenario renamed between the run and the read still points
  // somebody at the right file rather than at no file at all.
  return (file: _relative(feature.path), line: 1);
}

String _relative(String path) {
  final root = '${Directory.current.path}/';
  return path.startsWith(root) ? path.substring(root.length) : path;
}

/// JUnit, grouped by feature file.
///
/// **`classname` is what the feature tests and `name` is the scenario**, so any reader of this
/// file — a CI plugin, an IDE, a spreadsheet — groups the way the summary does.
String _junit(Run run) {
  final grouped = _group(run);
  final suites = <String, List<Result>>{
    for (final path in grouped.features.keys.toList()..sort())
      _titleOf(grouped.features[path]!): grouped.features[path]!,
    for (final suite in grouped.others.keys.toList()..sort()) _shorten(suite): grouped.others[suite]!,
  };

  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<testsuites tests="${run.results.length}" '
      'failures="${run.results.where((result) => !result.passed).length}" '
      'time="${_plainSeconds(run.took)}">',
    );

  suites.forEach((name, results) {
    final failures = results.where((result) => !result.passed).length;
    final skipped = results.where((result) => result.skipped).length;
    out.writeln(
      '  <testsuite name="${_xml(name)}" tests="${results.length}" '
      'failures="$failures" errors="0" skipped="$skipped" '
      'time="${_plainSeconds(results.fold(Duration.zero, (all, one) => all + one.took))}" '
      'timestamp="${run.at.toUtc().toIso8601String()}">',
    );
    for (final result in results) {
      final scenario = result.feature == null ? result.name : result.scenario;
      out.write(
        '    <testcase classname="${_xml(name)}" name="${_xml(scenario)}" '
        'time="${_plainSeconds(result.took)}"',
      );
      if (result.skipped) {
        out
          ..writeln('>')
          ..writeln('      <skipped/>')
          ..writeln('    </testcase>');
      } else if (result.passed) {
        out.writeln('/>');
      } else {
        out
          ..writeln('>')
          ..writeln(
            '      <failure message="${_xml(_firstLine(result.detail))}">'
            '${_xml(result.detail)}</failure>',
          )
          ..writeln('    </testcase>');
      }
    }
    out.writeln('  </testsuite>');
  });

  out.writeln('</testsuites>');
  return out.toString();
}

String _firstLine(String detail) {
  final said = _worthAnnotating(detail);
  if (said.isEmpty) return 'failed with nothing said';
  final end = said.indexOf('\n');
  return end < 0 ? said : said.substring(0, end);
}

String _plainSeconds(Duration took) => (took.inMilliseconds / 1000).toStringAsFixed(3);

/// A workflow command is one line, so what would end it is encoded rather than sent.
String _command(String text) => text.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

/// A property is inside a comma-separated list, so it loses two more characters.
String _property(String text) => _command(text).replaceAll(':', '%3A').replaceAll(',', '%2C');

/// Enough escaping that a table cell holding a pipe stays one cell.
String _markdown(String text) => text.replaceAll('|', r'\|').replaceAll('\n', ' ');

String _xml(String text) =>
    text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _page(Run run) {
  final grouped = _group(run);
  final covered = grouped.features;
  final others = grouped.others;

  final ids = covered.keys.toList()..sort();
  final failed = run.results.where((result) => !result.passed).length;
  final skipped = run.results.where((result) => result.skipped).length;

  final page = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="en"><head><meta charset="utf-8">')
    ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('<title>Porelo frontend — test report</title>')
    ..writeln('<style>${_style()}</style>')
    ..writeln('</head><body>')
    ..writeln('<header>')
    ..writeln('<h1>Porelo frontend</h1>')
    ..writeln(
      '<p class="run ${failed == 0 ? 'ok' : 'bad'}">'
      '${run.results.length} tests · '
      '${_verdict(failed, skipped)} · '
      '${_seconds(run.took)} · ${_when(run.at)}</p>',
    )
    ..writeln('</header>');

  page
    ..writeln('<section>')
    ..writeln('<h2>Scenarios</h2>')
    ..writeln(
      '<p class="note">One section per <code>.feature</code> file, named by what it says '
      'it tests. Passing is not the same as covered: a file with one shallow scenario shows as '
      'green as one with twelve.</p>',
    );

  for (final path in ids) {
    final scenarios = covered[path]!;
    final broken = scenarios.where((result) => !result.passed).length;
    page
      ..writeln('<article class="${broken == 0 ? 'ok' : 'bad'}">')
      ..writeln(
        '<h3>${_escape(_titleOf(scenarios))}'
        '<span class="id">${_escape(Result.shorten(path))}</span>'
        '<span class="count">${scenarios.length} scenario'
        '${scenarios.length == 1 ? '' : 's'}'
        '${broken == 0 ? '' : ', $broken failed'}</span></h3>',
      )
      ..writeln('<ul>');
    for (final scenario in scenarios) {
      page.writeln(
        '<li class="${_class(scenario)}">'
        '<span class="mark">${_mark(scenario)}</span>'
        '${_escape(scenario.scenario)}'
        '<span class="took">${_seconds(scenario.took)}</span></li>',
      );
      if (!scenario.passed && scenario.detail.isNotEmpty) {
        page.writeln('<pre>${_escape(scenario.detail)}</pre>');
      }
    }
    page
      ..writeln('</ul>')
      ..writeln('</article>');
  }

  page.writeln('</section>');

  if (others.isNotEmpty) {
    page
      ..writeln('<section>')
      ..writeln('<h2>Everything else</h2>')
      ..writeln(
        '<p class="note">Tests that guard the client, the wire and the rules, rather '
        'than a screen.</p>',
      );
    final suites = others.keys.toList()..sort();
    for (final suite in suites) {
      final tests = others[suite]!;
      final broken = tests.where((result) => !result.passed).length;
      page
        ..writeln('<article class="${broken == 0 ? 'ok' : 'bad'}">')
        ..writeln(
          '<h3>${_escape(_shorten(suite))}'
          '<span class="count">${tests.length} test'
          '${tests.length == 1 ? '' : 's'}'
          '${broken == 0 ? '' : ', $broken failed'}</span></h3>',
        )
        ..writeln('<ul>');
      for (final test in tests) {
        page.writeln(
          '<li class="${_class(test)}">'
          '<span class="mark">${_mark(test)}</span>'
          '${_escape(test.name)}'
          '<span class="took">${_seconds(test.took)}</span></li>',
        );
        if (!test.passed && test.detail.isNotEmpty) {
          page.writeln('<pre>${_escape(test.detail)}</pre>');
        }
      }
      page
        ..writeln('</ul>')
        ..writeln('</article>');
    }
    page.writeln('</section>');
  }

  page.writeln('</body></html>');
  return page.toString();
}

/// How a run went, in the words every output uses: a skip is said, never folded into "passed".
String _verdict(int failed, int skipped) => <String>[
  if (failed > 0) '$failed failed',
  if (skipped > 0) '$skipped skipped',
  if (failed == 0) skipped == 0 ? 'all passed' : 'the rest passed',
].join(', ');

String _class(Result result) => result.skipped
    ? 'none'
    : result.passed
    ? 'ok'
    : 'bad';

String _mark(Result result) => result.skipped
    ? '–'
    : result.passed
    ? '✓'
    : '✗';

String _shorten(String path) {
  final index = path.indexOf('/test/');
  return index < 0 ? path : path.substring(index + 1);
}

String _seconds(Duration took) =>
    '${(took.inMilliseconds / 1000).toStringAsFixed(took.inMilliseconds < 1000 ? 2 : 1)} s';

String _when(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)} ${_two(at.hour)}:${_two(at.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');

String _escape(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _style() => '''
:root {
  --ink: #16211f; --paper: #fbfaf7; --line: #ddd8cf; --quiet: #6b7370;
  --good: #1c6b52; --bad: #a3282a; --none: #8a8378;
}
@media (prefers-color-scheme: dark) {
  :root {
    --ink: #e6e3dc; --paper: #14181a; --line: #2c3335; --quiet: #98a09d;
    --good: #63c4a1; --bad: #e88a86; --none: #7e8683;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 2rem 1.25rem 4rem; background: var(--paper); color: var(--ink);
  font: 15px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
header, section { max-width: 60rem; margin: 0 auto; }
h1 { font-size: 1.5rem; margin: 0 0 .25rem; }
h2 { font-size: 1.1rem; margin: 2.5rem 0 .5rem; }
h3 {
  font-size: .95rem; margin: 0; padding: .6rem .85rem; display: flex;
  align-items: baseline; gap: .6rem; border-bottom: 1px solid var(--line);
}
.run { margin: 0; font-variant-numeric: tabular-nums; }
.run.ok { color: var(--good); } .run.bad { color: var(--bad); }
.note { color: var(--quiet); font-size: .875rem; margin: .25rem 0 1rem; }
article {
  border: 1px solid var(--line); border-radius: 8px; margin: 0 0 .85rem; overflow: hidden;
}
article.bad { border-color: var(--bad); }
.id {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 600;
  color: var(--quiet);
}
.count { margin-left: auto; color: var(--quiet); font-weight: 400; font-size: .8rem; }
ul { list-style: none; margin: 0; padding: .35rem 0; }
li {
  display: flex; align-items: baseline; gap: .6rem; padding: .25rem .85rem;
}
li.ok .mark { color: var(--good); } li.bad .mark { color: var(--bad); }
li.none { color: var(--quiet); } li.none .mark { color: var(--none); }
.mark { width: 1rem; flex: none; }
.took {
  margin-left: auto; color: var(--quiet); font-size: .8rem; font-variant-numeric: tabular-nums;
}
pre {
  margin: .25rem .85rem .75rem 2.5rem; padding: .7rem .85rem; overflow-x: auto;
  background: rgba(127,127,127,.1); border-left: 3px solid var(--bad); border-radius: 4px;
  font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; white-space: pre-wrap;
}
code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .9em; }
''';
