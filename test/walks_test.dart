@Tags(<String>['documents'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The walks written for the MVP's paths point at keys the interface really has: a key renamed in
/// the code without its walk is a walk that points at nothing, found here rather than by the person
/// walking it.
void main() {
  final code = <String>[
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File && file.path.endsWith('.dart')) file.readAsStringSync(),
  ].join('\n');

  bool inTheCode(String key) {
    // `!` waits for it to go, `filled:` for something in it: the key itself is what is in the code.
    final plain = key.replaceFirst(RegExp('^!'), '').replaceFirst(RegExp('^(filled|usable):'), '');
    // The walk panel's own, which guided_walk counts as on screen wherever the panel is: a push step
    // waits on one that never goes, so it stays until Next instead of being skipped.
    if (plain.startsWith('walk-')) return true;
    // A button found by its words: the words are in the code.
    if (plain.startsWith('text:')) return code.contains(plain.substring('text:'.length));
    // A key with a part that varies, such as a machine's name: what comes before the part is.
    final fixed = plain.split('*').first.trimRight();
    if (code.contains("'$fixed")) return true;
    // A key named after what it shows, as `project default` is `'project ${project.name}'`.
    final space = plain.indexOf(' ');
    return space > 0 && code.contains("'${plain.substring(0, space + 1)}\${");
  }

  final walks = <File>[
    for (final file in Directory('doc/walks').listSync().whereType<File>())
      if (file.path.endsWith('.json')) file,
  ];

  // Without this a moved or emptied directory makes no test below, and the suite green.
  test('there are walks to check', () => expect(walks, isNotEmpty));

  for (final file in walks) {
    test('${file.uri.pathSegments.last} points only at what the interface has', () {
      final walk = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final steps = walk['steps'] as List<dynamic>;
      expect(steps, isNotEmpty);
      for (final step in steps.cast<Map<String, dynamic>>()) {
        final keys = <String>[
          ...switch (step['at']) {
            final List<dynamic> many => many.map((each) => '$each'),
            null || '' => const <String>[],
            final one => <String>['$one'],
          },
          if ('${step['then'] ?? ''}'.isNotEmpty) '${step['then']}',
        ];
        for (final key in keys) {
          expect(inTheCode(key), isTrue, reason: '"$key" in "${step['say']}"');
        }
      }
    });
  }
}
