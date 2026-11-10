import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';

/// A credential a host's vault lacks beside the agent, as `CanStart` and a task carry it.
void main() {
  Map<String, dynamic> entry({Object? storeCommand = const <String>['porelo', 'host', 'forge-token']}) =>
      <String, dynamic>{
        'for': 'builds',
        'credential': 'forge.person',
        'storeCommand': storeCommand,
        'afterStore': 'ask-again',
      };

  Map<String, dynamic> ready(Map<String, dynamic> more) => <String, dynamic>{
    'ready': true,
    'outcome': 'READY',
    'agent': 'an-agent',
    'provider': 'a-provider',
    'credential': 'a-provider',
    ...more,
  };

  Task task(Map<String, dynamic> more) => Task.from(<String, dynamic>{
    'name': 'porelo-checkout-fix',
    'project': 'checkout',
    'buildReader': 'host-forge',
    'buildProblem': 'your vault does not hold forge.person; run porelo host forge-token on this host',
    ...more,
  });

  // Harm: a host's ask lost on the way leaves a task blind to its builds, and nobody is told.
  test('a start names each credential the host lacks, with its command and what follows it', () {
    final answer = Readiness.from(
      ready(<String, dynamic>{
        'missing': <Object?>[entry()],
      }),
    );
    expect(answer.ready, isTrue, reason: 'what is missing beside the agent holds nothing back');
    final only = answer.missing.single;
    expect((only.purpose, only.credential, only.afterStore), ('builds', 'forge.person', 'ask-again'));
    expect(only.storeCommand, <String>['porelo', 'host', 'forge-token']);
  });

  // Harm: a button that runs a command on a host where an older daemon named none.
  test('an older daemon says nothing missing, and a task from it carries no credential', () {
    expect(Readiness.from(ready(const <String, dynamic>{})).missing, isEmpty);
    expect(task(const <String, dynamic>{}).buildsCredential, isNull);
    for (final odd in <Object?>[null, 'builds', 7, <Object?>[]]) {
      expect(task(<String, dynamic>{'buildsCredential': odd}).buildsCredential, isNull, reason: '$odd');
    }
    expect(Readiness.from(ready(<String, dynamic>{'missing': 'builds'})).missing, isEmpty);
  });

  // Harm: a word the window cannot show as it is, or that ends the line, runs something else in the host's shell.
  test('a store command with a word that is no plain text is never offered to run', () {
    for (final words in <Object?>[
      <Object?>['porelo', 'host', 'forge-token\nrm -rf ~'],
      <Object?>['porelo', '', 'forge-token'],
      <Object?>['porelo', 7, 'forge-token'],
      <Object?>['porelo', 'host\u2028forge-token'],
      'porelo host forge-token',
      null,
    ]) {
      final missing = Readiness.from(
        ready(<String, dynamic>{
          'missing': <Object?>[entry(storeCommand: words)],
        }),
      ).missing;
      expect(missing.single.storeCommand, isEmpty, reason: '$words');
      expect(missing.single.credential, 'forge.person', reason: 'what is missing is still said');
    }
  });

  // Harm: an unknown value read as a known one sends the person to the wrong remedy.
  test('a task names the credential its builds wait for, and an unknown value stays as it came', () {
    final waiting = task(<String, dynamic>{
      'buildsCredential': <String, dynamic>{...entry(), 'for': 'mirrors', 'afterStore': 'reboot'},
    }).buildsCredential!;
    expect((waiting.purpose, waiting.credential, waiting.afterStore), ('mirrors', 'forge.person', 'reboot'));
    expect(waiting.storeCommand, <String>['porelo', 'host', 'forge-token']);
  });

  // Harm: a start that names no forge, or the wrong one, sends the person to make a token for another forge.
  test('an entry names the forge whose builds it reads, and an older daemon names none', () {
    final named = Readiness.from(
      ready(<String, dynamic>{
        'missing': <Object?>[
          <String, dynamic>{...entry(), 'forge': 'github'},
        ],
      }),
    ).missing.single;
    expect(named.forge, 'github');
    final older = Readiness.from(
      ready(<String, dynamic>{
        'missing': <Object?>[entry()],
      }),
    ).missing.single;
    expect(older.forge, '', reason: 'a daemon before the field names no forge');
    final odd = task(<String, dynamic>{
      'buildsCredential': <String, dynamic>{...entry(), 'forge': 7},
    }).buildsCredential!;
    expect(odd.forge, '', reason: 'a forge that is no text is none');
  });

  // Harm: a forge named with a line break or a control shows the person words the machine did not mean, or none.
  test('a forge that is no plain word names none, and a task names its forge', () {
    for (final odd in <Object?>['   ', 'github\nrm -rf ~', 'git\u2028hub', 'github\x00', '\x1b[31mgithub']) {
      final read = Readiness.from(
        ready(<String, dynamic>{
          'missing': <Object?>[
            <String, dynamic>{...entry(), 'forge': odd},
          ],
        }),
      ).missing.single;
      expect(read.forge, '', reason: '$odd');
    }
    expect(
      task(<String, dynamic>{
        'buildsCredential': <String, dynamic>{...entry(), 'forge': ' github '},
      }).buildsCredential!.forge,
      'github',
    );
  });
}
