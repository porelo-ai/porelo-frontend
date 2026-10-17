import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the feature files to the one thing the build report reads off them.
///
/// **The `Feature:` line is the report row.** It used to carry a requirement id, and the ids are
/// gone: every requirement file this project had has been finished and deleted, so a row headed by
/// an id named a document nobody could open. What the row says now is what the file tests, in one
/// short sentence — the only description of it that survives the requirement it came from.
void main() {
  final features = <File>[
    for (final root in <String>['test/features', 'integration_test'])
      if (Directory(root).existsSync())
        ...Directory(root).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.feature')),
  ];

  test('the feature directory was found at all', () {
    // Without this every test below passes by examining nothing.
    expect(features, isNotEmpty);
  });

  test('every feature is named by one short sentence', () {
    for (final file in features) {
      final named = file
          .readAsLinesSync()
          .where((line) => line.startsWith('Feature:'))
          .map((line) => line.substring('Feature:'.length).trim())
          .toList();

      expect(named, hasLength(1), reason: '${file.path} must have exactly one Feature line');
      expect(named.single, isNotEmpty, reason: '${file.path} names nothing');
      // Seventy, because the row is a table cell beside a path and a count. A title that wraps
      // makes the table unreadable at exactly the width somebody scans it.
      expect(
        named.single.length,
        lessThanOrEqualTo(70),
        reason: '${file.path}: "${named.single}" is ${named.single.length} characters',
      );
    }
  });

  test('no two features are named the same thing', () {
    final named = <String, String>{};
    for (final file in features) {
      for (final line in file.readAsLinesSync()) {
        if (!line.startsWith('Feature:')) continue;
        final title = line.substring('Feature:'.length).trim();
        // The title is the group key in the summary, the JUnit file and the annotation. Two files
        // sharing one would silently merge into a row that is right about neither.
        expect(named, isNot(contains(title)), reason: '${file.path} and ${named[title]} are named the same');
        named[title] = file.path;
      }
    }
  });

  test('no channel question number survives in the code or the features', () {
    // A question number is a position in an append-only chat log. A requirement id at least names a
    // document that once existed; this names a line nobody reading the class can reach.
    final question = RegExp(r'\bQ[A-Z]\d{1,3}\b');
    final offending = <String>[];
    final sources = _sources().toList();
    // Without git's list every file would be skipped, and this test would pass by reading nothing.
    expect(sources.where((file) => file.path.endsWith('.yml')), isNotEmpty);
    for (final file in sources) {
      for (final line in file.readAsLinesSync()) {
        if (question.hasMatch(line)) offending.add('${file.path}: ${line.trim()}');
      }
    }
    expect(
      offending,
      isEmpty,
      reason:
          'these cite a question in the agent channel, which no reader of the code can '
          'follow:\n${offending.join('\n')}',
    );
  });
}

/// Every text file this repository keeps outside its Markdown, this test excepted: it names the
/// shapes it refuses, so scanning itself would fail on its own rules.
Iterable<File> _sources() {
  final listed = Process.runSync(
    'git',
    <String>['ls-files', '-z'],
    environment: <String, String>{'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'},
  );
  if (listed.exitCode != 0) throw StateError('git ls-files exited ${listed.exitCode}: ${listed.stderr}');
  final tracked = listed.stdout as String;
  return tracked
      .split('\x00')
      .where((path) => path.isNotEmpty && !path.endsWith('.md') && !path.startsWith('doc/walks/'))
      .where((path) => _text.any(path.endsWith))
      .where((path) => path != 'test/features_named_test.dart')
      .map(File.new)
      .where((file) => file.existsSync());
}

/// What is written by hand here; generated and binary files carry no citations.
const _text = <String>['.dart', '.feature', '.yml', '.yaml', '.sh', '.xml', '.cmake', '.txt', '.cc', '.h', '.json'];
