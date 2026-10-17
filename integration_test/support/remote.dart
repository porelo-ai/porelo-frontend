import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'e2e.dart';

/// Runs [script] on the test machine through ssh, and answers what it printed.
///
/// On standard input, never `-n`: `ssh -n` connects it to `/dev/null`, so the script would never
/// arrive and the run would say nothing and exit 0. The agent `tool/e2e.sh` raised holds the key.
Future<String> onTheTestMachine(String script) async {
  final ssh = await Process.start('ssh', <String>['-o', 'BatchMode=yes', E2e.host, 'bash -s']);
  ssh.stdin.write(script);
  await ssh.stdin.close();
  // Both at once: read one after the other, a script that writes a lot to the second would wait on
  // a full pipe that nobody reads.
  final (out, err) = await (
    ssh.stdout.transform(const SystemEncoding().decoder).join(),
    ssh.stderr.transform(const SystemEncoding().decoder).join(),
  ).wait;
  final code = await ssh.exitCode;
  if (code != 0) throw StateError('on the test machine, exit $code: $err');
  return out.trim();
}

/// Where the scenario's repository was made on the test machine, once it was.
String? theRepository;

/// Where the key the test machine's account has is, once a step has made sure of one.
String? theKey;

/// The machine's own sentence from the connection wizard's check, read before it was left.
String? theCheckSaid;

/// The vault entry a scenario copied a key into, once the machine listed it.
String? theVaultEntry;

/// The file name of the message a scenario had held for a person on the test machine.
String? theHeldMessage;

/// What the interface showed as that message's text.
String? theMessageRead;

/// Removes what a step made on the test machine **when the scenario ends, passed or failed**:
/// [remove] runs then, whatever came before it, and [leftOver] after it must print none of [names],
/// or the scenario fails naming what it left. A scenario's own last step removes the same and checks
/// it; this is for one that went red before it got there.
void removeAfterwards({required String remove, required String leftOver, required List<String> names}) =>
    addTearDown(() async {
      await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"\n$remove');
      final left = await onTheTestMachine('PATH="\$HOME/.local/bin:\$PATH"\n$leftOver');
      final still = <String>[
        for (final name in names)
          if (left.contains(name)) name,
      ];
      if (still.isNotEmpty) throw StateError('left on the test machine: ${still.join(', ')}');
    });

/// What removes a task and its project, whichever is still there: tolerant, since the scenario's own
/// step may have removed them already.
String removingTheWork(String task, String project) =>
    '''
porelo task stop "$task" >/dev/null 2>&1 || true
porelo task remove --force "$task" >/dev/null 2>&1 || true
porelo project unfollow --force "$project" >/dev/null 2>&1 || true
rm -rf "\$HOME/$project" "\$HOME/$project-backend.git"
''';

/// What [removeAfterwards] reads to say what is left of work: every task and every project.
const listingTheWork = 'porelo task list 2>/dev/null; porelo project list 2>/dev/null; ls "\$HOME"';
