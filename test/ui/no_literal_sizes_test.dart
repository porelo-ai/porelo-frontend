import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the rule that nothing outside `tokens.dart` spells out a spacing, a width or a radius.
///
/// Scattered numbers cannot be told apart afterwards: nobody can say which of a dozen `560`s meant
/// the same thing, so each size is named once in `tokens.dart` and read from there.
void main() {
  final files = Directory('lib/src/ui')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart') && !file.path.endsWith('/tokens.dart'))
      .toList();

  test('the interface directory was found at all', () {
    // Without this the test below passes by examining nothing.
    expect(files, isNotEmpty);
  });

  test('the pattern recognizes a literal size in every shape it looks for', () {
    for (final line in <String>[
      'SizedBox(width: 560, child: x)',
      'height: 2,',
      'Icon(Icons.add, size: 32)',
      "width: wide ? 280 : 240,",
      'BoxConstraints(maxWidth: 560)',
      'CircularProgressIndicator(strokeWidth: 2)',
      'EdgeInsets.all(16)',
      'EdgeInsets.fromLTRB(Space.normal, 0, 8, Space.small)',
      'EdgeInsets.symmetric(horizontal: Space.small, vertical: 1)',
      'BorderRadius.circular(8)',
    ]) {
      expect(literalSizes(line), isNotEmpty, reason: line);
    }
    for (final line in <String>[
      'SizedBox(width: Sizes.dialog, child: x)',
      'EdgeInsets.fromLTRB(Space.normal, 0, Space.normal, Space.small)',
      'TextStyle(fontSize: 12)',
      'minLines: 3,',
      "Text('width: 3')",
      '// width: 3',
    ]) {
      expect(literalSizes(line), isEmpty, reason: line);
    }
  });

  test('no size is spelled out outside tokens.dart', () {
    final found = <String>[
      for (final file in files)
        for (final hit in literalSizes(file.readAsStringSync())) '${file.path}: $hit',
    ];
    expect(found, isEmpty, reason: 'name these in lib/src/ui/tokens.dart:\n${found.join('\n')}');
  });
}

const _named =
    r'\b(?:width|height|size|minWidth|maxWidth|minHeight|maxHeight|dimension|radius|strokeWidth|'
    r'thickness|indent|endIndent|spacing|runSpacing|horizontal|vertical|left|top|right|bottom)'
    r'\s*:\s*[^,;()]*';

final _shapes = RegExp('$_named|\\bEdgeInsets\\w*\\.\\w+\\([^)]*\\)|Radius\\.circular\\([^)]*\\)');

/// A number other than zero, standing on its own rather than inside a name.
final _number = RegExp(r'(?:^|[^\w.])(\d+(?:\.\d+)?)(?![\w.])');

/// Every size in [source] that is a literal rather than a token; strings and comments are skipped.
List<String> literalSizes(String source) {
  final code = source
      .replaceAll(RegExp(r"'(?:\\.|[^'\\\n])*'"), "''")
      .replaceAll(RegExp(r'"(?:\\.|[^"\\\n])*"'), '""')
      .replaceAll(RegExp(r'//[^\n]*'), '');
  return <String>[
    for (final match in _shapes.allMatches(code))
      if (_number.allMatches(match[0]!).any((n) => double.parse(n[1]!) != 0)) match[0]!.trim(),
  ];
}
