@Tags(<String>['documents'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the documentation to what exists.
///
/// **A finished requirement's file is deleted**, and a pointer to it still reads as one that can be
/// followed. The index once linked five files it said two paragraphs earlier were gone, and the
/// document every newcomer was told to read first described a contract that no longer existed.
void main() {
  // The channel transcript is history and is never edited, so it is not read here.
  final docs = <File>[
    for (final file in Directory('.').listSync().whereType<File>())
      if (file.path.endsWith('.md') && !file.uri.pathSegments.last.startsWith('.')) file,
    for (final root in <String>['doc', 'issues'])
      ...Directory(root).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.md')),
  ];

  test('the docs and the issues were found at all', () {
    // Without this the link test below passes by examining nothing.
    expect(docs.where((doc) => doc.path.startsWith('doc/')), isNotEmpty);
    expect(docs.where((doc) => doc.path.startsWith('issues/')), isNotEmpty);
  });

  /// The decisions document's own index.
  ///
  /// **An index maintained by hand is a second copy of the truth**, and two copies is how one
  /// becomes wrong. Rather than generating the table, this holds it to the sections.
  group('the decisions index', () {
    final decisions = File('doc/decisions.md').readAsLinesSync();
    final sections = <String>[
      for (final line in decisions)
        if (line.startsWith('## ')) line.substring(3).trim(),
    ];
    final rows = <String>[
      for (final line in decisions)
        if (line.startsWith('| [')) line,
    ];

    test('every decision has a row and every row a decision, in the same order', () {
      expect(sections, isNotEmpty);
      expect(
        rows,
        hasLength(sections.length),
        reason: 'the table and the document disagree on how many decisions there are',
      );
      for (final (index, section) in sections.indexed) {
        final anchor = section.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 _-]'), '').replaceAll(' ', '-');
        expect(
          rows[index],
          contains('(#$anchor)'),
          reason: 'the link in row ${index + 1} does not reach section ${index + 1}, "$section"',
        );
      }
    });

    test('no decision carries a date', () {
      // When a decision was taken is in git; a date in a description is stale the day after.
      final dated = [
        for (final line in decisions)
          if (RegExp(r'\b\d{4}-\d\d-\d\d\b').hasMatch(line)) line,
      ];
      expect(dated, isEmpty, reason: 'these lines carry a date:\n${dated.join('\n')}');
    });
  });

  test('every relative link in the docs resolves', () {
    final dead = <String>[
      for (final doc in docs)
        for (final match in RegExp(r'\]\(([^)\s]+)\)').allMatches(doc.readAsStringSync()))
          if (_isDead(doc, match[1]!)) '${doc.path}: ${match[1]}',
    ];
    expect(dead, isEmpty, reason: 'these links point at nothing:\n${dead.join('\n')}');
  });
}

bool _isDead(File doc, String target) {
  if (target.startsWith('http') || target.startsWith('mailto:') || target.startsWith('#')) {
    return false;
  }
  final path = '${doc.parent.path}/${target.split('#').first}';
  return !File(path).existsSync() && !Directory(path).existsSync();
}
