import 'dart:convert';
import 'dart:io';

import 'package:porelo_host/porelo_host.dart';

const _usage = '''
porelo-host up|down --project NAME --account NAME --public-key FILE --identity FILE --collection FILE
            (--scaleway-project ID [--zone fr-par-1] | --given ADDRESS --host-key "TYPE BASE64")
            [--login-user NAME] [--distribution releases|snapshots]
            [--tresor NAME] [--vpn-peer-public-key KEY --vpn-peer-address ADDRESS] [--answers-on-stdin]
porelo-host key set|forget PROVIDER
porelo-host --version

  up      rents the project's host, or finds it again by its tag, and runs the playbook there; it
          stops once with 75 for the person, and an up given --answers-on-stdin goes on
  down    runs the down play, then gives the host back
  key     keeps a provider's key in the system's own store, read from standard input, or forgets it;
          the key is never an argument, and nothing is said of it but that it was kept

One JSON line per step on standard output; the words for a person on standard error.
Exit: 0 done, 64 usage, 65 refused, 69 unreachable, 70 an unforeseen fault, 75 waiting for the person.

--scaleway-project rents from Scaleway Elastic Metal, with the key `key set scaleway` kept.
--given names a machine that exists already, with its host key; nothing is rented or given back.
--answers-on-stdin reads one JSON object: driveEmail, drivePassword, driveCode, vaultPassphrase.''';

// Ends with the run's code at once: an HTTPS connection to the provider, kept for reuse, would hold
// the program open for its idle time otherwise.
Future<void> main(List<String> arguments) async {
  try {
    exit(await _run(arguments));
  } catch (e) {
    // Whatever was not foreseen still ends in one plain line, never a stack trace.
    stderr.writeln('porelo-host: $e');
    exit(70);
  }
}

/// The version this command was built as, given by `dart compile exe -Dporelo_host.version=…`.
const _version = String.fromEnvironment('porelo_host.version', defaultValue: 'unreleased');

Future<int> _run(List<String> arguments) async {
  if (arguments.length == 1 && arguments.first == '--version') {
    stdout.writeln(_version);
    return Exit.done;
  }
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
  const needed = <String>['project', 'account', 'public-key', 'identity', 'collection'];
  final missing = needed.where((n) => !options.containsKey(n)).toList();
  if (missing.isNotEmpty) return _wrong('missing ${missing.map((n) => '--$n').join(', ')}');
  final given = options.containsKey('given');
  if (given == options.containsKey('scaleway-project')) return _wrong('either --scaleway-project or --given');
  if (given && !options.containsKey('host-key')) return _wrong('--given needs --host-key');
  final HostProvider provider;
  if (given) {
    provider = GivenMachine(address: options['given']!, hostKey: options['host-key']!);
  } else {
    final store = SecretStore.forThisSystem();
    final String? key;
    try {
      key = await store.read(providerKeyName('scaleway'));
    } on SecretStoreFailed catch (e) {
      stderr.writeln('porelo-host: $e');
      return Exit.refused;
    } finally {
      await store.close();
    }
    if (key == null) return _wrong('no key for scaleway is kept: run `porelo-host key set scaleway` first');
    provider = ScalewayElasticMetal(
      api: scalewayOverHttps(key),
      projectId: options['scaleway-project']!,
      zone: options['zone'] ?? 'fr-par-1',
    );
  }

  final answers = answersOnStdin ? Answers.fromJson(await stdin.transform(utf8.decoder).join()) : const Answers();
  final ssh = OpenSsh(knownHosts: File('${_stateDirectory()}/known_hosts'), identity: options['identity']!);
  final run = HostRun(
    provider: provider,
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
