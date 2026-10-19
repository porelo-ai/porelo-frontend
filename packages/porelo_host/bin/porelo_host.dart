import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

const _usage = '''
porelo-host up|down --project NAME --account NAME --public-key FILE --identity FILE --collection FILE
            --given ADDRESS --host-key "TYPE BASE64" [--login-user NAME] [--distribution releases|snapshots]
            [--tresor NAME] [--vpn-peer-public-key KEY --vpn-peer-address ADDRESS] [--answers-on-stdin]
porelo-host key set|forget PROVIDER

  up      rents the project's host, or finds it again by its tag, and runs the playbook there; it
          stops once with 75 for the person, and an up given --answers-on-stdin goes on
  down    runs the down play, then gives the host back
  key     keeps a provider's key in the system's own store, read from standard input, or forgets it;
          the key is never an argument, and nothing is said of it but that it was kept

One JSON line per step on standard output; the words for a person on standard error.
Exit: 0 done, 64 usage, 65 refused, 69 unreachable, 75 waiting for the person.

--given names a machine that exists already; a provider to rent from comes with its adapter.
--answers-on-stdin reads one JSON object: driveEmail, drivePassword, vaultPassphrase.''';

Future<void> main(List<String> arguments) async {
  exitCode = await _run(arguments);
}

Future<int> _run(List<String> arguments) async {
  if (arguments.isNotEmpty && arguments.first == 'key') return _key(arguments.sublist(1));
  if (arguments.isEmpty || !<String>{'up', 'down'}.contains(arguments.first)) return _wrong('up or down first');
  final verb = arguments.first;
  final options = <String, String>{};
  var answersOnStdin = false;
  for (var i = 1; i < arguments.length; i++) {
    final name = arguments[i];
    if (name == '--answers-on-stdin') {
      answersOnStdin = true;
    } else if (name.startsWith('--') && i + 1 < arguments.length) {
      options[name.substring(2)] = arguments[++i];
    } else {
      return _wrong('$name is not an option');
    }
  }
  const needed = <String>['project', 'account', 'public-key', 'identity', 'collection', 'given', 'host-key'];
  final missing = needed.where((n) => !options.containsKey(n)).toList();
  if (missing.isNotEmpty) return _wrong('missing ${missing.map((n) => '--$n').join(', ')}');

  final answers = answersOnStdin ? Answers.fromJson(await stdin.transform(utf8.decoder).join()) : const Answers();
  final ssh = OpenSsh(knownHosts: File('${_stateDirectory()}/known_hosts'), identity: options['identity']!);
  final run = HostRun(
    provider: GivenMachine(address: options['given']!, hostKey: options['host-key']!),
    remote: ssh,
    trust: ssh.trust,
    emit: (step) {
      stdout.writeln(step.toLine());
      final said = <String?>[step.words, step.fix].whereType<String>().join(': ');
      stderr.writeln('${step.step} ${step.state.name}${said.isEmpty ? '' : ' — $said'}');
    },
  );
  final plan = HostPlan(
    project: options['project']!,
    account: options['account']!,
    publicKey: (await File(options['public-key']!).readAsString()).trim(),
    collection: options['collection']!,
    loginUser: options['login-user'] ?? 'ubuntu',
    distribution: options['distribution'] ?? 'releases',
    tresor: options['tresor'],
    vpnPeerPublicKey: options['vpn-peer-public-key'],
    vpnPeerAddress: options['vpn-peer-address'],
  );
  return verb == 'up' ? run.up(plan, answers: answers) : run.down(plan);
}

/// `key set PROVIDER` and `key forget PROVIDER`.
Future<int> _key(List<String> arguments) async {
  if (arguments.length != 2 || !<String>{'set', 'forget'}.contains(arguments.first)) {
    return _wrong('key set PROVIDER or key forget PROVIDER');
  }
  final name = providerKeyName(arguments[1]);
  final store = SecretStore.forThisSystem();
  try {
    if (arguments.first == 'forget') {
      await store.remove(name);
      stderr.writeln('porelo-host: the key for ${arguments[1]} is forgotten');
      return Exit.done;
    }
    // One line; a key typed at a terminal is not echoed.
    if (stdin.hasTerminal) stdin.echoMode = false;
    final line = stdin.readLineSync(encoding: utf8);
    if (stdin.hasTerminal) stdin.echoMode = true;
    final key = line?.trim() ?? '';
    if (key.isEmpty) return _wrong('no key on standard input');
    await store.write(name, key);
    stderr.writeln('porelo-host: the key for ${arguments[1]} is kept in the system\'s store');
    return Exit.done;
  } on SecretStoreFailed catch (e) {
    stderr.writeln('porelo-host: $e');
    return Exit.refused;
  } finally {
    await store.close();
  }
}

/// Where this command keeps its own `known_hosts`: never the person's own.
String _stateDirectory() {
  final env = Platform.environment;
  if (Platform.isWindows) return '${env['LOCALAPPDATA']}\\porelo-host';
  final state = env['XDG_STATE_HOME'];
  return state != null && state.isNotEmpty ? '$state/porelo-host' : '${env['HOME']}/.local/state/porelo-host';
}

int _wrong(String why) {
  stderr.writeln('porelo-host: $why\n\n$_usage');
  return Exit.usage;
}
