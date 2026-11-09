import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/token_giving.dart';

void main() {
  // Harm: the token is fed to one machine twice at once, over two root logins, when it is asked from two rows.
  test('a machine is given the token once at a time', () async {
    final given = <String>[];
    final answers = <String, Completer<String?>>{};
    final tokens = TokenGiving((host, {atOnce = false}) {
      given.add(host);
      return (answers[host] = Completer<String?>()).future;
    });
    addTearDown(tokens.dispose);

    final first = tokens.give('build');
    expect(tokens.busy('build'), isNotNull);
    final second = tokens.give('build');
    expect(given, ['build'], reason: 'a second ask while the first runs gives nothing');
    expect(await second, isNotNull, reason: 'it says why not');
    final other = tokens.give('spare');
    expect(given, ['build', 'spare'], reason: 'another machine is its own');

    answers['build']!.complete(null);
    expect(await first, isNull);
    expect(tokens.busy('build'), isNull);
    answers['spare']!.complete('refused');
    expect(await other, 'refused');

    final again = tokens.give('build');
    expect(given, ['build', 'spare', 'build'], reason: 'once it ended it can be given again');
    answers['build']!.complete(null);
    await again;
  });
}
