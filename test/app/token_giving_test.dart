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

  // Harm: a hand-over nobody pressed runs beside a press to the same machine, so the token is fed twice at once.
  test('a run of its own and a pressed give to one machine go one at a time', () async {
    final pressed = Completer<String?>();
    final tokens = TokenGiving((host, {atOnce = false}) => pressed.future);
    addTearDown(tokens.dispose);
    final ran = <String>[];
    final ranRelease = Completer<void>();

    final press = tokens.give('build');
    final beside = await tokens.run('build', () async {
      ran.add('beside the press');
      return 'ran';
    });
    expect(beside, isNull, reason: 'busy: not run');
    expect(ran, isEmpty);
    pressed.complete(null);
    await press;

    final run = tokens.run('build', () async {
      ran.add('own');
      await ranRelease.future;
      return 'done';
    });
    expect(await tokens.give('build'), isNotNull, reason: 'a press while it runs says why it gives nothing');
    expect(tokens.busy('build'), isNotNull);
    ranRelease.complete();
    expect(await run, 'done');
    expect(ran, ['own']);
    expect(tokens.busy('build'), isNull, reason: 'once it ended, the machine can be given again');
  });
}
