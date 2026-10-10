import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds every test that reads a document to the `documents` tag.
///
/// A change to documents or issues runs only `flutter test --tags documents`, so a test that reads a
/// document without the tag is skipped exactly when the change it guards is made.
void main() {
  final tests = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .where((file) => file.path.replaceAll(r'\', '/') != 'test/documents_tagged_test.dart')
      .toList();
  final readers = <String>{
    for (final file in tests)
      if (_readsADocument.any((shape) => shape.hasMatch(file.readAsStringSync()))) file.path.replaceAll(r'\', '/'),
  };

  test('the tests that read a document are found', () {
    // Without these two the shapes below match nothing, and the next test passes by checking nothing.
    expect(readers, containsAll(<String>['test/docs_test.dart', 'test/walks_test.dart']));
  });

  test('every test that reads a document carries the documents tag', () {
    final untagged = <String>[
      for (final path in readers)
        if (!_tagged.hasMatch(File(path).readAsStringSync())) path,
    ];
    expect(untagged, isEmpty,
        reason: 'these read a document but are left out of `flutter test --tags documents`:\n'
            '${untagged.join('\n')}');
  });
}

/// How a test reaches the repository's documents: a file or directory under `doc/` or `issues/`, a
/// Markdown file at the root, or a listing kept to its Markdown. A path built in a scratch directory
/// starts with `$` and is no document.
final _readsADocument = <RegExp>[
  RegExp(r"\b(File|Directory)\(\s*'(doc|issues)(/[^']*)?'"),
  RegExp(r"'(doc|issues)'"),
  RegExp(r"\bFile\(\s*'[^'$/]*\.md'"),
  RegExp(r"(?<!!)\b\w+\.path\.endsWith\('\.md'\)"),
];

final _tagged = RegExp(r"@Tags\(\s*(<String>)?\[[^\]]*'documents'");
